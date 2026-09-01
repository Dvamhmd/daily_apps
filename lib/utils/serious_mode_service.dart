import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model_serious_mode.dart';
import '../models/model_sheets_config.dart';
import '../models/model_todo.dart';

class SeriousModeService {
  static const String prefKeyActiveMode = 'daily_apps_is_serious_mode_active';
  static const String prefKeyCurrentUser = 'daily_apps_serious_current_user';
  static const String prefKeyAllUsers = 'daily_apps_serious_all_users';
  static const String prefKeyProcessedGroups = 'daily_apps_serious_processed_groups';
  static const String prefKeyNormalTodoGroups = 'daily_apps_todo_groups_v1';
  static const String prefKeySeriousTodoGroups = 'daily_apps_serious_todo_groups_v1';
  static const String prefKeyPunishmentStates = 'daily_apps_serious_punishment_states_v1';
  static const String prefKeyHideCommitmentWarning = 'daily_apps_serious_hide_commitment_warning';

  /// Generator key SharedPreferences spesifik per user untuk status jangan tampilkan peringatan komitmen
  static Future<bool> isHideCommitmentWarning([String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? (await getCurrentUser())?.id;
    final key = uid != null ? '${prefKeyHideCommitmentWarning}_$uid' : prefKeyHideCommitmentWarning;
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setHideCommitmentWarning(bool hide, [String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? (await getCurrentUser())?.id;
    final key = uid != null ? '${prefKeyHideCommitmentWarning}_$uid' : prefKeyHideCommitmentWarning;
    await prefs.setBool(key, hide);
  }

  /// Generator key SharedPreferences spesifik per user untuk mengisolasi data task Mode Serius
  static String getSeriousTodoGroupsKey([String? userIdentifier]) {
    if (userIdentifier != null && userIdentifier.trim().isNotEmpty) {
      final clean = userIdentifier.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return 'daily_apps_serious_todo_groups_v1_$clean';
    }
    return prefKeySeriousTodoGroups;
  }

  /// Mencari data Todo lokal pengguna dari berbagai kemungkinan key (Username, ID, atau Legacy)
  static Future<String?> findExistingUserTodoData(
    SharedPreferences prefs,
    SeriousUser user,
  ) async {
    // 1. Cek key berdasarkan username
    final usernameKey = getSeriousTodoGroupsKey(user.username);
    if (prefs.containsKey(usernameKey)) {
      final data = prefs.getString(usernameKey);
      if (data != null && data.isNotEmpty) return data;
    }

    // 2. Cek key berdasarkan user.id
    final idKey = getSeriousTodoGroupsKey(user.id);
    if (prefs.containsKey(idKey)) {
      final data = prefs.getString(idKey);
      if (data != null && data.isNotEmpty) return data;
    }

    // 3. Cek legacy global key
    if (prefs.containsKey(prefKeySeriousTodoGroups)) {
      final data = prefs.getString(prefKeySeriousTodoGroups);
      if (data != null && data.isNotEmpty) return data;
    }

    return null;
  }

  /// Generator key SharedPreferences spesifik per user untuk status hukuman
  static String getPunishmentStatesKey([String? userIdentifier]) {
    if (userIdentifier != null && userIdentifier.trim().isNotEmpty) {
      final clean = userIdentifier.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return 'daily_apps_serious_punishment_states_v1_$clean';
    }
    return prefKeyPunishmentStates;
  }

  /// Generator key SharedPreferences spesifik per user untuk section yang telah diproses
  static String getProcessedGroupsKey([String? userIdentifier]) {
    if (userIdentifier != null && userIdentifier.trim().isNotEmpty) {
      final clean = userIdentifier.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return 'daily_apps_serious_processed_groups_$clean';
    }
    return prefKeyProcessedGroups;
  }

  /// Identifier unik & stabil untuk penyimpanan lokal (mengutamakan username)
  static String getUserStorageIdentifier(SeriousUser? user) {
    if (user == null) return '';
    final username = user.username.trim();
    if (username.isNotEmpty) return username;
    return user.id.trim();
  }

  /// Ambil key aktif saat ini sesuai mode dan akun yang login
  static Future<String> getActiveTodoStorageKey() async {
    final isSerious = await isSeriousModeActive();
    if (isSerious) {
      final user = await getCurrentUser();
      return getSeriousTodoGroupsKey(getUserStorageIdentifier(user));
    }
    return prefKeyNormalTodoGroups;
  }

  /// URL Web App Google Apps Script yang telah di-setup untuk Mode Serius Leaderboard
  static const String defaultSeriousWebAppUrl =
      'https://script.google.com/macros/s/AKfycbxRRS8EtrvH_a3J3woHETHUP8uSGjUT9E5qlvrD940IVz_6w9dFSXO6JSm1zZssofc-8w/exec';

  /// 1. Perhitungan Poin Berdasarkan Jumlah Tugas Selesai Per Section / Hari
  static int calculatePoints(int completedCount) {
    if (completedCount <= 0) return 0;
    if (completedCount <= 2) return 1; // 1-2: 1
    if (completedCount <= 5) return 2; // 3-5: 2
    if (completedCount <= 8) return 4; // 6-8: 4
    if (completedCount <= 10) return 5; // 9-10: 5
    if (completedCount <= 15) return 7; // 11-15: 7
    return 10; // >15: 10
  }

  /// 2. Evaluasi Section Tanggal yang Telah Lewat dengan Tugas Belum Selesai
  static SeriousSectionEvaluation? evaluateSection(TodoDateGroup group) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groupDate = DateTime(group.date.year, group.date.month, group.date.day);

    // Hanya evaluasi jika tanggal hari sudah melewati section (tanggal lampau)
    if (!groupDate.isBefore(today)) {
      return null;
    }

    final completed = group.completedCount;
    final pending = group.pendingCount;

    // Hanya jika ada tugas yang tidak diselesaikan saat tanggal sudah melewati section
    if (pending <= 0) {
      return null;
    }

    final points = calculatePoints(completed);

    String message;
    bool isPunishmentRequired = true;
    bool isPunishmentOptional = false;
    bool isExempt = false;

    if (completed == 0) {
      message =
          'Sudah pemalas, susah, tidak punya komitmen diri! mau jadi apa lu? anggota DPR?!!';
      isPunishmentRequired = true;
    } else if (completed >= 1 && completed <= 2) {
      message =
          'Wkwkw cemen, udah kerjaan dikit, masih kelewat pulak, emang dasarnya orang mageran, suruh tertib aja susah! ayo perbaiki diri!';
      isPunishmentRequired = true;
    } else if (completed >= 3 && completed <= 5) {
      message =
          'Hadehh, besok lagi bagi waktu yang bener, jangan kebanyakan scroll';
      isPunishmentRequired = true;
    } else if (completed >= 6 && completed <= 8) {
      message =
          'Gapapa bro, besok lebih perhatian lagi yaa, wajar manusia bukan nabi boyyy';
      isPunishmentRequired = true;
    } else if (completed >= 9 && completed <= 10) {
      message =
          'kamu udah hebat kok, beberapa tugas ngga harus diselesaikan hari ini, besok masih ada waktu, semangatt!';
      isPunishmentRequired = true;
    } else if (completed >= 11 && completed <= 15) {
      message = 'Aman aja kingg, kamu bebas mau ambil hukuman atau ngga';
      isPunishmentRequired = false;
      isPunishmentOptional = true; // Boleh milih mau ambil hukuman atau ngga
    } else {
      // > 15
      message =
          'daripada kita mikirin hukuman lebih baik kita mikirin jam istirahat kamu, udah yaa istirahat aja';
      isPunishmentRequired = false;
      isExempt = true; // Tidak akan mendapat hukuman karena over produktif
    }

    return SeriousSectionEvaluation(
      groupId: group.id,
      date: group.date,
      completedCount: completed,
      pendingCount: pending,
      message: message,
      isPunishmentRequired: isPunishmentRequired,
      isPunishmentOptional: isPunishmentOptional,
      isExempt: isExempt,
      pointsEarned: points,
    );
  }

  /// Evaluasi seluruh section yang membutuhkan perhatian / hukuman
  static List<SeriousSectionEvaluation> evaluateAllPastSections(
      List<TodoDateGroup> groups) {
    final List<SeriousSectionEvaluation> results = [];
    for (final group in groups) {
      if (group.isArchived) continue;
      final eval = evaluateSection(group);
      if (eval != null) {
        results.add(eval);
      }
    }
    return results;
  }

  /// 3. Status Aktif Mode Serius (Tersimpan sebagai default)
  static Future<bool> isSeriousModeActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKeyActiveMode) ?? false;
  }

  static Future<void> setSeriousModeActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyActiveMode, active);
  }

  /// 4. Manajemen Akun Pengguna Mode Serius (Terintegrasi Google Spreadsheets)
  static Future<SeriousUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKeyCurrentUser);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return SeriousUser.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('Error decoding SeriousUser: $e');
      }
    }
    return null;
  }

  static Future<void> saveCurrentUser(SeriousUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyCurrentUser, jsonEncode(user.toJson()));
    await _saveUserToLocalDatabase(user);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKeyCurrentUser);
    await prefs.setBool(prefKeyActiveMode, false);
  }

  static final http.Client _httpClient = http.Client();
  static List<SeriousUser>? _cachedRemoteUsers;
  static DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(seconds: 20);

  static const String prefKeySeriousWebAppUrl = 'daily_apps_serious_webapp_url';

  /// URL Spreadsheet Web App terpusat khusus untuk Mode Serius To Do List
  static Future<String> getEffectiveSpreadsheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(prefKeySeriousWebAppUrl);
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim();
    }
    return defaultSeriousWebAppUrl;
  }

  static Future<void> setSeriousWebAppUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeySeriousWebAppUrl, url.trim());
  }

  /// Helper untuk mengirim HTTP Request ke Google Apps Script Web App (Mendukung Flutter Web & Mobile)
  static Future<Map<String, dynamic>?> _sendSpreadsheetRequest(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final targetUrl = await getEffectiveSpreadsheetUrl();
    if (targetUrl.isEmpty) return null;
    final bodyJson = jsonEncode(payload);
    final uri = Uri.parse(targetUrl);
    final action = payload['action']?.toString() ?? 'get_leaderboard';

    // 1. Pada Flutter Web atau Read Request: gunakan GET query parameter (paling cepat & anti-CORS preflight)
    if (kIsWeb || action.startsWith('get_')) {
      try {
        final getUri = uri.replace(
          queryParameters: {
            'action': action,
            'payload': bodyJson,
          },
        );
        final getRes = await _httpClient.get(getUri).timeout(timeout);
        if (getRes.statusCode == 200) {
          final decoded = jsonDecode(getRes.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (e) {
        debugPrint('Spreadsheet GET request error: $e');
      }
    }

    // 2. Pada non-web atau Fallback: gunakan POST request langsung
    if (!kIsWeb) {
      try {
        final postRes = await _httpClient.post(
          uri,
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: bodyJson,
        ).timeout(timeout);

        if (postRes.statusCode >= 300 && postRes.statusCode < 400) {
          final loc = postRes.headers['location'];
          if (loc != null) {
            final redirectedRes =
                await _httpClient.get(Uri.parse(loc)).timeout(timeout);
            if (redirectedRes.statusCode == 200) {
              return jsonDecode(redirectedRes.body) as Map<String, dynamic>;
            }
          }
        } else if (postRes.statusCode == 200) {
          return jsonDecode(postRes.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Spreadsheet POST request error: $e');
      }
    }

    return null;
  }

  /// Mengambil seluruh data user langsung dari Google Spreadsheets (dengan In-Memory Cache)
  static Future<List<SeriousUser>> fetchUsersFromSpreadsheet({
    bool forceRefresh = false,
  }) async {
    // Gunakan in-memory cache jika masih fresh dan tidak di-force
    if (!forceRefresh &&
        _cachedRemoteUsers != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTtl) {
      return List<SeriousUser>.from(_cachedRemoteUsers!);
    }

    final List<SeriousUser> remoteUsers = [];
    try {
      final res = await _sendSpreadsheetRequest({
        'action': 'get_serious_users',
      });

      if (res != null) {
        final usersRaw = res['users'] ?? res['data'];
        if (usersRaw is List) {
          for (final item in usersRaw) {
            if (item is Map<String, dynamic>) {
              remoteUsers.add(SeriousUser.fromJson(item));
            } else if (item is Map) {
              remoteUsers
                  .add(SeriousUser.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching users from spreadsheet: $e');
    }

    // Perbarui cache in-memory dan database lokal jika data remote berhasil diambil
    if (remoteUsers.isNotEmpty) {
      _cachedRemoteUsers = List<SeriousUser>.from(remoteUsers);
      _lastFetchTime = DateTime.now();
      _saveAllLocalUsers(remoteUsers);
    }

    return remoteUsers;
  }

  /// Pengecekan apakah username sudah ada di Spreadsheet (Case-Insensitive)
  static Future<bool> isUsernameRegisteredInSpreadsheet(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;

    // 1. Cek online dari Spreadsheet (memanfaatkan cache jika ada)
    final remoteUsers = await fetchUsersFromSpreadsheet();
    if (remoteUsers.isNotEmpty) {
      final exists =
          remoteUsers.any((u) => u.username.trim().toLowerCase() == clean);
      if (exists) return true;
    }

    // 2. Cek juga di penyimpanan lokal sebagai cadangan
    final localUsers = await _getAllLocalUsers();
    return localUsers.any((u) => u.username.trim().toLowerCase() == clean);
  }

  /// Registrasi Pengguna Baru Mode Serius:
  /// 1. Validasi lokal & langsung kirim 1x request atomik ke Spreadsheet
  /// 2. Simpan lokal & aktifkan mode serius
  static Future<Map<String, dynamic>> registerUser({
    required String username,
    required String password,
    required String displayName,
    String? avatarBase64,
    int avatarIndex = 0,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPass = password.trim();
    final cleanName = displayName.trim();

    if (cleanUsername.isEmpty || cleanPass.isEmpty) {
      return {
        'success': false,
        'message': 'Username dan password wajib diisi!'
      };
    }

    if (cleanPass.length < 4) {
      return {
        'success': false,
        'message': 'Password minimal 4 karakter!'
      };
    }

    // Cek di cache/lokal dulu untuk respon cepat
    if (_cachedRemoteUsers != null) {
      final existsInCache = _cachedRemoteUsers!
          .any((u) => u.username.trim().toLowerCase() == cleanUsername);
      if (existsInCache) {
        return {
          'success': false,
          'message':
              'Username "$cleanUsername" sudah digunakan di Spreadsheets. Silakan gunakan username lain atau login!'
        };
      }
    }

    final newUser = SeriousUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      username: cleanUsername,
      password: cleanPass,
      displayName: cleanName.isNotEmpty ? cleanName : cleanUsername,
      avatarBase64: avatarBase64,
      avatarIndex: avatarIndex,
      totalPoints: 0,
      totalTasksCompleted: 0,
      totalPunishmentsTaken: 0,
      registeredAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    // Kirim langsung ke Google Spreadsheets (1 round-trip)
    final syncResult = await _sendSpreadsheetRequest({
      'action': 'register_serious_user',
      'user': newUser.toJson(),
    });

    if (syncResult != null &&
        syncResult['status'] == 'error' &&
        syncResult['code'] == 'USERNAME_EXISTS') {
      return {
        'success': false,
        'message':
            'Username "$cleanUsername" sudah ada di Spreadsheets. Silakan login!'
      };
    }

    // Simpan lokal & perbarui cache
    await saveCurrentUser(newUser);
    await setSeriousModeActive(true);

    _cachedRemoteUsers ??= [];
    _cachedRemoteUsers!.removeWhere((u) => u.username == newUser.username);
    _cachedRemoteUsers!.add(newUser);
    _lastFetchTime = DateTime.now();

    // Redundancy background sync
    _syncUserToSpreadsheet(newUser);

    return {'success': true, 'user': newUser};
  }

  /// Login Pengguna Mode Serius:
  /// 1. Username dan password dicocokkan langsung dari data yang ada di Google Spreadsheets
  /// 2. Fallback ke lokal jika spreadsheet sedang tidak terjangkau (offline)
  static Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
    bool forceOnlineOnly = false,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanUsername.isEmpty || cleanPass.isEmpty) {
      return {'success': false, 'message': 'Username dan password wajib diisi!'};
    }

    // 1. Ambil data terbaru dari Spreadsheet
    List<SeriousUser> users = await fetchUsersFromSpreadsheet();

    // 2. Jika offline / kosong, gunakan data lokal
    if (users.isEmpty && !forceOnlineOnly) {
      users = await _getAllLocalUsers();
    }

    // 3. Cocokkan username di data Spreadsheet
    final matchedUser = users.firstWhere(
      (u) => u.username.trim().toLowerCase() == cleanUsername,
      orElse: () => SeriousUser(
        id: '',
        username: '',
        password: '',
        displayName: '',
      ),
    );

    if (matchedUser.id.isEmpty) {
      return {
        'success': false,
        'message': 'Akun "$cleanUsername" tidak ditemukan di Spreadsheets. Silakan buat username & password baru!'
      };
    }

    // 4. Cocokkan password dari Spreadsheet
    if (matchedUser.password.trim() != cleanPass) {
      return {
        'success': false,
        'message': 'Password yang Anda masukkan salah!'
      };
    }

    // 5. Berhasil login -> Update status aktif & simpan ke lokal
    matchedUser.lastActiveAt = DateTime.now();
    await saveCurrentUser(matchedUser);
    await setSeriousModeActive(true);

    // Sync status aktif ke Spreadsheet
    _syncUserToSpreadsheet(matchedUser);

    return {'success': true, 'user': matchedUser};
  }

  /// Sinkronisasi Poin dan Total Task Pengguna
  /// Aturan:
  /// - Hari ini/masa depan: Poin normal berdasarkan jumlah task selesai.
  /// - Tanggal lampau:
  ///   - Jika semua task selesai: Poin penuh.
  ///   - Jika ada task terlewat dan SEMUA hukuman olahraga diselesaikan: Poin bertambah sesuai total poin task terjadwal hari itu.
  ///   - Jika menyerah / belum menyelesaikan hukuman: Setiap task terlewat yang belum diselesaikan hukumannya mengurangi 1 poin (-1 per task).
  static Future<void> recalculateAndSyncUserProgress(
      List<TodoDateGroup> groups, {SeriousUser? targetUser}) async {
    final user = targetUser ?? await getCurrentUser();
    if (user == null) return;

    // Jika groups kosong (misal saat login akun yang belum punya task lokal di HP ini),
    // jangan menghapus total points & tasks yang sudah ada dari spreadsheet.
    if (groups.isEmpty) {
      return;
    }

    final allStates = await _getAllPunishmentStates(getUserStorageIdentifier(user));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalPoints = 0;
    int totalCompleted = 0;

    for (final g in groups) {
      final comp = g.completedCount;
      totalCompleted += comp;

      final groupDate = DateTime(g.date.year, g.date.month, g.date.day);
      final isPast = groupDate.isBefore(today);

      if (!isPast) {
        // Section hari ini atau masa depan: Poin reguler
        totalPoints += calculatePoints(comp);
      } else {
        // Section tanggal lampau
        final pending = g.pendingCount;
        if (pending == 0) {
          totalPoints += calculatePoints(comp);
        } else {
          final state = allStates[g.id];
          if (state != null && state.isFullyCompleted) {
            // Pengguna telah menyelesaikan seluruh hukuman olahraga fisik
            // Poin dipertahankan/ditambahkan penuh sesuai seluruh jadwal hari itu
            totalPoints += calculatePoints(g.totalCount);
          } else {
            // Menyerah atau belum selesai:
            // Setiap task yang tidak dikerjakan (dan tidak ditebus hukuman) mengurangi 1 poin
            final basePoints = calculatePoints(comp);
            final remainingMissed = (state != null)
                ? state.remainingCount
                : pending;
            totalPoints += (basePoints - remainingMissed);
          }
        }
      }
    }

    user.totalPoints = totalPoints;
    user.totalTasksCompleted = totalCompleted;
    user.lastActiveAt = DateTime.now();

    await saveCurrentUser(user);
    _syncUserToSpreadsheet(user);
  }

  /// Catat Hukuman yang Diambil
  static Future<void> recordPunishmentTaken(String punishmentTitle, {String? userId}) async {
    final user = await getCurrentUser();
    if (user == null) return;
    user.totalPunishmentsTaken += 1;
    await saveCurrentUser(user);
    _syncUserToSpreadsheet(user);
  }

  /// Ambil Leaderboard Seluruh Users dari Spreadsheet (Diurutkan berdasarkan poin tertinggi)
  static Future<List<SeriousUser>> getLeaderboard() async {
    final List<SeriousUser> users = [];

    // 1. Ambil data online langsung dari Spreadsheet
    final remoteUsers = await fetchUsersFromSpreadsheet();
    if (remoteUsers.isNotEmpty) {
      users.addAll(remoteUsers);
    }

    // 2. Gabungkan dengan data user lokal jika ada data baru
    final localUsers = await _getAllLocalUsers();
    for (final loc in localUsers) {
      final idx = users.indexWhere(
        (u) =>
            (u.id.isNotEmpty && u.id == loc.id) ||
            (u.username.isNotEmpty &&
                u.username.toLowerCase() == loc.username.toLowerCase()),
      );
      if (idx == -1) {
        users.add(loc);
      } else {
        if (loc.totalPoints > users[idx].totalPoints) {
          users[idx] = loc;
        }
      }
    }

    // 3. Pastikan user saat ini ada di list
    final currentUser = await getCurrentUser();
    if (currentUser != null && currentUser.username.isNotEmpty) {
      final idx = users.indexWhere(
        (u) =>
            (u.id.isNotEmpty && u.id == currentUser.id) ||
            (u.username.isNotEmpty &&
                u.username.toLowerCase() == currentUser.username.toLowerCase()),
      );
      if (idx == -1) {
        users.add(currentUser);
      } else {
        if (currentUser.totalPoints >= users[idx].totalPoints) {
          users[idx] = currentUser;
        }
      }
    }

    // 4. Urutkan berdasarkan total poin tertinggi (Rank #1, #2, #3, ...)
    users.sort((a, b) {
      final cmp = b.totalPoints.compareTo(a.totalPoints);
      if (cmp != 0) return cmp;
      return b.totalTasksCompleted.compareTo(a.totalTasksCompleted);
    });

    return users;
  }

  /// Ambil Top 3 Pengguna Teratas dari Spreadsheet dengan Poin Paling Tinggi
  static Future<List<SeriousUser>> getTop3Leaderboard() async {
    final leaderboard = await getLeaderboard();
    return leaderboard.take(3).toList();
  }

  /// 5. Daftar 20 Hukuman Olahraga Fisik
  static const List<SeriousPunishmentItem> punishmentList = [
    SeriousPunishmentItem(
      id: 'w1',
      title: 'Push Up 20x',
      description: 'Lakukan 20x push up dengan form sempurna untuk melatih dada, bahu, dan trisep.',
      emoji: '💪',
      category: 'Fisik',
      repsOrDuration: '20 Repetisi',
      targetMuscle: 'Dada & Lengan',
    ),
    SeriousPunishmentItem(
      id: 'w2',
      title: 'Plank 60 Detik',
      description: 'Tahan posisi plank lurus selama 1 menit penuh untuk memperkuat otot core perut.',
      emoji: '⏱️',
      category: 'Fisik',
      repsOrDuration: '60 Detik',
      targetMuscle: 'Core & Perut',
    ),
    SeriousPunishmentItem(
      id: 'w3',
      title: 'Jumping Jacks 35x',
      description: 'Lompat buka-tutup tangan dan kaki 35x untuk membakar kalori dan kardio.',
      emoji: '⚡',
      category: 'Fisik',
      repsOrDuration: '35 Repetisi',
      targetMuscle: 'Kardio Full Body',
    ),
    SeriousPunishmentItem(
      id: 'w4',
      title: 'Squat 25x',
      description: 'Lakukan 25x squat mendalam dengan punggung tegak untuk otot paha & bokong.',
      emoji: '🏋️',
      category: 'Fisik',
      repsOrDuration: '25 Repetisi',
      targetMuscle: 'Paha & Kaki',
    ),
    SeriousPunishmentItem(
      id: 'w5',
      title: 'Burpees 10x',
      description: 'Lakukan 10x burpees penuh (squat-pushup-jump) untuk ledakan energi fisik.',
      emoji: '🔥',
      category: 'Fisik',
      repsOrDuration: '10 Repetisi',
      targetMuscle: 'Full Body Kardio',
    ),
    SeriousPunishmentItem(
      id: 'w6',
      title: 'Lunges 20x (10 Kiri & 10 Kanan)',
      description: 'Lakukan 20x forward lunges bergantian untuk melatih keseimbangan & kekuatan kaki.',
      emoji: '🦵',
      category: 'Fisik',
      repsOrDuration: '20 Repetisi',
      targetMuscle: 'Paha & Pinggul',
    ),
    SeriousPunishmentItem(
      id: 'w7',
      title: 'Mountain Climbers 30x',
      description: 'Gerakan lari mendaki di lantai 30x untuk memacu detak jantung dan perut.',
      emoji: '🏔️',
      category: 'Fisik',
      repsOrDuration: '30 Repetisi',
      targetMuscle: 'Perut & Kardio',
    ),
    SeriousPunishmentItem(
      id: 'w8',
      title: 'Sit Up 25x',
      description: 'Lakukan 25x sit up penuh sampai menyentuh lutut untuk mengencangkan perut.',
      emoji: '🎯',
      category: 'Fisik',
      repsOrDuration: '25 Repetisi',
      targetMuscle: 'Perut Atas',
    ),
    SeriousPunishmentItem(
      id: 'w9',
      title: 'Wall Sit 45 Detik',
      description: 'Sandarkan punggung ke tembok dengan posisi paha sejajar lantai selama 45 detik.',
      emoji: '🧱',
      category: 'Fisik',
      repsOrDuration: '45 Detik',
      targetMuscle: 'Paha Depan (Quads)',
    ),
    SeriousPunishmentItem(
      id: 'w10',
      title: 'High Knees 40x',
      description: 'Lari di tempat sambil mengangkat lutut setinggi pinggang sebanyak 40 repetisi.',
      emoji: '🏃',
      category: 'Fisik',
      repsOrDuration: '40 Repetisi',
      targetMuscle: 'Kardio & Kaki',
    ),
    SeriousPunishmentItem(
      id: 'w11',
      title: 'Calf Raises 35x',
      description: 'Jinjitkan tumit setinggi mungkin 35x untuk melatih otot betis dan pergelangan kaki.',
      emoji: '🦶',
      category: 'Fisik',
      repsOrDuration: '35 Repetisi',
      targetMuscle: 'Betis',
    ),
    SeriousPunishmentItem(
      id: 'w12',
      title: 'Shadow Boxing 1 Menit',
      description: 'Kombinasi pukulan jab-cross cepat di udara dengan footwork aktif selama 60 detik.',
      emoji: '🥊',
      category: 'Fisik',
      repsOrDuration: '60 Detik',
      targetMuscle: 'Bahu & Kardio',
    ),
    SeriousPunishmentItem(
      id: 'w13',
      title: 'Bicycle Crunches 30x',
      description: 'Gerakan mengayuh sepeda di lantai menyentuhkan siku ke lutut berlawanan 30x.',
      emoji: '🚴',
      category: 'Fisik',
      repsOrDuration: '30 Repetisi',
      targetMuscle: 'Perut Samping (Obliques)',
    ),
    SeriousPunishmentItem(
      id: 'w14',
      title: 'Russian Twists 30x',
      description: 'Duduk condong ke belakang lalu putar torso ke kiri & kanan 30 repetisi.',
      emoji: '🌪️',
      category: 'Fisik',
      repsOrDuration: '30 Repetisi',
      targetMuscle: 'Core & Obliques',
    ),
    SeriousPunishmentItem(
      id: 'w15',
      title: 'Butt Kicks 40x',
      description: 'Lari di tempat dengan tumit menendang ke belakang hingga menyentuh bokong 40x.',
      emoji: '⚡',
      category: 'Fisik',
      repsOrDuration: '40 Repetisi',
      targetMuscle: 'Hamstring & Kardio',
    ),
    SeriousPunishmentItem(
      id: 'w16',
      title: 'Arm Circles 1 Menit',
      description: 'Rentangkan kedua tangan lurus ke samping dan putar membentuk lingkaran selama 60 detik.',
      emoji: '🔄',
      category: 'Fisik',
      repsOrDuration: '60 Detik',
      targetMuscle: 'Bahu & Lengan',
    ),
    SeriousPunishmentItem(
      id: 'w17',
      title: 'Leg Raises 20x',
      description: 'Berbaring telentang dan angkat kedua kaki lurus ke atas tanpa menyentuh lantai 20x.',
      emoji: '🧘',
      category: 'Fisik',
      repsOrDuration: '20 Repetisi',
      targetMuscle: 'Perut Bawah',
    ),
    SeriousPunishmentItem(
      id: 'w18',
      title: 'Side Plank 60s (30s Kiri + 30s Kanan)',
      description: 'Tahan side plank bertumpu pada satu siku selama 30 detik tiap sisi.',
      emoji: '⏳',
      category: 'Fisik',
      repsOrDuration: '60 Detik',
      targetMuscle: 'Core & Bahu',
    ),
    SeriousPunishmentItem(
      id: 'w19',
      title: 'Jump Squat 15x',
      description: 'Lakukan squat kemudian melompat tinggi eksplosif ke atas sebanyak 15 repetisi.',
      emoji: '🚀',
      category: 'Fisik',
      repsOrDuration: '15 Repetisi',
      targetMuscle: 'Explosive Legs',
    ),
    SeriousPunishmentItem(
      id: 'w20',
      title: 'Step-ups / Naik Turun Tangga 30x',
      description: 'Naik dan turun satu anak tangga atau bangku pendek dengan tempo teratur 30x.',
      emoji: '🪜',
      category: 'Fisik',
      repsOrDuration: '30 Repetisi',
      targetMuscle: 'Kaki & Kardio',
    ),
  ];

  /// 6. Manajemen State Hukuman Per Section (Acak Otomatis Deterministik, Checklist & Menyerah)
  static Future<Map<String, SeriousGroupPunishmentState>> _getAllPunishmentStates([String? userIdentifier]) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveIdentifier = userIdentifier ?? getUserStorageIdentifier(await getCurrentUser());
    final key = getPunishmentStatesKey(effectiveIdentifier);

    String? raw = prefs.getString(key);
    // Legacy migration: jika key spesifik user belum ada tapi key legacy ada
    if ((raw == null || raw.isEmpty) && effectiveIdentifier.isNotEmpty && prefs.containsKey(prefKeyPunishmentStates)) {
      raw = prefs.getString(prefKeyPunishmentStates);
      if (raw != null && raw.isNotEmpty) {
        await prefs.setString(key, raw);
      }
    }

    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        return decoded.map(
          (k, value) => MapEntry(
            k,
            SeriousGroupPunishmentState.fromJson(value as Map<String, dynamic>),
          ),
        );
      } catch (e) {
        debugPrint('Error reading punishment states: $e');
      }
    }
    return {};
  }

  static Future<void> _saveAllPunishmentStates(
      Map<String, SeriousGroupPunishmentState> states, [String? userIdentifier]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveIdentifier = userIdentifier ?? getUserStorageIdentifier(await getCurrentUser());
      final key = getPunishmentStatesKey(effectiveIdentifier);
      final map = states.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(key, jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving punishment states: $e');
    }
  }

  /// Ambil atau buat daftar hukuman olahraga otomatis sebanyak jumlah checklist yang tidak tercentang
  static Future<SeriousGroupPunishmentState> getOrCreatePunishmentState(
    String groupId,
    int pendingCount, {
    String? userId,
  }) async {
    final allStates = await _getAllPunishmentStates(userId);
    if (allStates.containsKey(groupId)) {
      final existing = allStates[groupId]!;
      if (existing.assignedPunishmentIds.length == pendingCount || pendingCount <= 0) {
        return existing;
      }
    }

    final assignedIds = _generateRandomWorkoutIds(groupId, pendingCount);
    final newState = SeriousGroupPunishmentState(
      groupId: groupId,
      assignedPunishmentIds: assignedIds,
      completedPunishmentIds: [],
      isSurrendered: false,
      isFullyCompleted: false,
      updatedAt: DateTime.now(),
    );

    allStates[groupId] = newState;
    await _saveAllPunishmentStates(allStates, userId);
    return newState;
  }

  /// Generator acak unik dari 20 hukuman olahraga fisik (Stabil berdasarkan groupId)
  static List<String> _generateRandomWorkoutIds(String groupId, int count) {
    if (count <= 0) return [];
    final random = Random(groupId.hashCode.abs());
    final allIds = punishmentList.map((p) => p.id).toList();
    allIds.shuffle(random);

    final List<String> result = [];
    for (int i = 0; i < count; i++) {
      result.add(allIds[i % allIds.length]);
    }
    return result;
  }

  /// Ambil daftar objek [SeriousPunishmentItem] berdasarkan ID yang ditugaskan
  static List<SeriousPunishmentItem> getPunishmentItemsByIds(List<String> ids) {
    final Map<String, SeriousPunishmentItem> map = {
      for (final p in punishmentList) p.id: p
    };
    return ids.map((id) => map[id] ?? punishmentList.first).toList();
  }

  /// Update pengerjaan checklist hukuman
  static Future<SeriousGroupPunishmentState> togglePunishmentItemCompleted({
    required String groupId,
    required String punishmentId,
    required List<TodoDateGroup> allGroups,
    String? userId,
  }) async {
    final allStates = await _getAllPunishmentStates(userId);
    final state = allStates[groupId] ??
        SeriousGroupPunishmentState(
          groupId: groupId,
          assignedPunishmentIds: [punishmentId],
        );

    final updatedCompleted = List<String>.from(state.completedPunishmentIds);
    if (updatedCompleted.contains(punishmentId)) {
      updatedCompleted.remove(punishmentId);
    } else {
      updatedCompleted.add(punishmentId);
    }

    final isAllDone = state.assignedPunishmentIds.isNotEmpty &&
        updatedCompleted.length >= state.assignedPunishmentIds.length;

    final newState = state.copyWith(
      completedPunishmentIds: updatedCompleted,
      isFullyCompleted: isAllDone,
      isSurrendered: isAllDone ? false : state.isSurrendered,
      updatedAt: DateTime.now(),
    );

    allStates[groupId] = newState;
    await _saveAllPunishmentStates(allStates, userId);

    if (isAllDone) {
      await recordPunishmentTaken('Menyelesaikan ${newState.totalAssigned} Latihan Fisik', userId: userId);
    }

    await recalculateAndSyncUserProgress(allGroups);
    return newState;
  }

  /// Menyerah pada hukuman section tertentu (Menerapkan penalti poin -1 per task)
  static Future<SeriousGroupPunishmentState> surrenderPunishment({
    required String groupId,
    required List<TodoDateGroup> allGroups,
    String? userId,
  }) async {
    final allStates = await _getAllPunishmentStates(userId);
    final state = allStates[groupId] ??
        SeriousGroupPunishmentState(
          groupId: groupId,
          assignedPunishmentIds: [],
        );

    final newState = state.copyWith(
      isSurrendered: true,
      isFullyCompleted: false,
      updatedAt: DateTime.now(),
    );

    allStates[groupId] = newState;
    await _saveAllPunishmentStates(allStates, userId);

    await recalculateAndSyncUserProgress(allGroups);
    return newState;
  }


  // Helper Private Methods
  static Future<List<SeriousUser>> _getAllLocalUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKeyAllUsers);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list
            .map((item) => SeriousUser.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error reading all users: $e');
      }
    }
    return [];
  }

  static Future<void> _saveAllLocalUsers(List<SeriousUser> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefKeyAllUsers,
        jsonEncode(users.map((u) => u.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving all local users: $e');
    }
  }

  static Future<void> _saveUserToLocalDatabase(SeriousUser user) async {
    final allUsers = await _getAllLocalUsers();
    final idx = allUsers.indexWhere((u) => u.id == user.id || u.username.toLowerCase() == user.username.toLowerCase());
    if (idx != -1) {
      allUsers[idx] = user;
    } else {
      allUsers.add(user);
    }
    await _saveAllLocalUsers(allUsers);
  }

  static final Set<String> _syncingUserKeys = {};

  /// Sinkronisasi data user ke Spreadsheet Apps Script (Single dispatch & anti-duplikasi)
  static Future<void> _syncUserToSpreadsheet(SeriousUser user) async {
    final syncKey = '${user.id}_${user.totalPoints}_${user.totalTasksCompleted}_${user.totalPunishmentsTaken}';
    if (_syncingUserKeys.contains(syncKey)) return;
    _syncingUserKeys.add(syncKey);

    final targetUrl = await getEffectiveSpreadsheetUrl();
    if (targetUrl.isEmpty) return;
    final payload = {
      'action': 'sync_serious_user',
      'user': user.toJson(),
    };
    final bodyJson = jsonEncode(payload);
    final uri = Uri.parse(targetUrl);

    try {
      if (kIsWeb) {
        // Di Flutter Web / Chrome, gunakan single GET request agar tidak terjadi CORS redirect retry ganda
        final getUri = uri.replace(
          queryParameters: {
            'action': 'sync_serious_user',
            'payload': bodyJson,
          },
        );
        await http.get(getUri).timeout(const Duration(seconds: 6));
      } else {
        // Di Mobile / Desktop
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: bodyJson,
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode >= 300 && response.statusCode < 400) {
          final loc = response.headers['location'];
          if (loc != null) {
            await http.get(Uri.parse(loc));
          }
        }
      }
    } catch (e) {
      debugPrint('Sync serious user to sheet error: $e');
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        _syncingUserKeys.remove(syncKey);
      });
    }
  }

  static Timer? _tasksSyncDebounceTimer;
  static String _lastSyncedTasksHash = '';

  /// Mengambil seluruh daftar task pengguna dari Spreadsheet (untuk login di HP baru / sinkronisasi multi-device)
  static Future<List<TodoDateGroup>> fetchUserTasksFromSpreadsheet(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return [];

    try {
      final res = await _sendSpreadsheetRequest({
        'action': 'get_serious_tasks',
        'username': cleanUsername,
      });

      if (res != null && res['status'] == 'success') {
        final tasksRaw = res['tasks'] ?? res['data'];
        if (tasksRaw is List) {
          final List<TodoDateGroup> groups = [];
          for (final item in tasksRaw) {
            if (item is Map<String, dynamic>) {
              groups.add(TodoDateGroup.fromJson(item));
            } else if (item is Map) {
              groups.add(TodoDateGroup.fromJson(Map<String, dynamic>.from(item)));
            }
          }
          return groups;
        } else if (res['rawTasksJson'] is String && (res['rawTasksJson'] as String).isNotEmpty) {
          final decoded = jsonDecode(res['rawTasksJson'] as String);
          if (decoded is List) {
            return decoded
                .map((item) => TodoDateGroup.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching user tasks from spreadsheet: $e');
    }
    return [];
  }

  /// Ambil dan simpan cache task user ke SharedPreferences saat login
  static Future<List<TodoDateGroup>> fetchAndCacheUserTasksFromSpreadsheet(SeriousUser user) async {
    final groups = await fetchUserTasksFromSpreadsheet(user.username);
    if (groups.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final userKey = getSeriousTodoGroupsKey(getUserStorageIdentifier(user));
      final encoded = jsonEncode(groups.map((g) => g.toJson()).toList());
      await prefs.setString(userKey, encoded);
    }
    return groups;
  }

  /// Sinkronisasi daftar task ke Cloud Spreadsheet dengan Debounce Non-Blocking (Tanpa lag di UI)
  static void scheduleTasksCloudSync(SeriousUser? user, List<TodoDateGroup> groups) {
    if (user == null || user.username.trim().isEmpty) return;

    _tasksSyncDebounceTimer?.cancel();
    _tasksSyncDebounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final encoded = jsonEncode(groups.map((g) => g.toJson()).toList());
      final hash = '${user.username}_${encoded.hashCode}';
      if (_lastSyncedTasksHash == hash) return;
      _lastSyncedTasksHash = hash;

      final payload = {
        'action': 'sync_serious_tasks',
        'username': user.username.trim().toLowerCase(),
        'tasksJson': encoded,
      };

      try {
        await _sendSpreadsheetRequest(payload);
      } catch (e) {
        debugPrint('Schedule tasks cloud sync error: $e');
      }
    });
  }

  /// Template Kode Google Apps Script untuk penanganan Mode Serius di Spreadsheet
  static String getSeriousModeAppsScriptCode() {
    return '''
// === HANDLER GOOGLE APPS SCRIPT UNTUK MODE SERIUS (USERS, LEADERBOARD & CLOUD TASKS) ===
function handleSeriousModeActions(data, ss) {
  var action = data.action;
  var userSheetName = "Users_Mode_Serius";
  var sheet = ss.getSheetByName(userSheetName);
  var headers = [
    "ID", "Username", "Password", "Display Name", 
    "Avatar Index", "Avatar Base64", "Total Points", 
    "Total Tasks Completed", "Total Punishments Taken", 
    "Registered At", "Last Active At"
  ];
  
  if (!sheet) {
    sheet = ss.insertSheet(userSheetName);
    sheet.appendRow(headers);
    sheet.getRange("A1:K1").setFontWeight("bold").setBackground("#1E293B").setFontColor("#F59E0B");
    sheet.setFrozenRows(1);
  } else {
    // Sinkronkan baris 1 header agar kolom Password selalu muncul di Kolom C
    var currentHeader = sheet.getRange(1, 1, 1, headers.length).getValues()[0];
    var needsUpdate = false;
    for (var h = 0; h < headers.length; h++) {
      if (currentHeader[h] !== headers[h]) {
        needsUpdate = true;
        break;
      }
    }
    if (needsUpdate) {
      sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
      sheet.getRange("A1:K1").setFontWeight("bold").setBackground("#1E293B").setFontColor("#F59E0B");
      sheet.setFrozenRows(1);
    }
  }

  // 1. GET ALL USERS / LEADERBOARD (SORTED TOP HIGHEST POINTS)
  if (action === "get_serious_users" || action === "get_leaderboard") {
    var dataRange = sheet.getDataRange();
    var values = dataRange.getValues();
    var users = [];
    
    for (var r = 1; r < values.length; r++) {
      var row = values[r];
      if (!row[1] || row[1].toString().trim() === "") continue; // Skip jika username kosong
      
      users.push({
        id: row[0] ? row[0].toString() : "",
        username: row[1] ? row[1].toString() : "",
        password: row[2] ? row[2].toString() : "",
        displayName: row[3] ? row[3].toString() : (row[1] ? row[1].toString() : "Player"),
        avatarIndex: parseInt(row[4]) || 0,
        avatarBase64: row[5] ? row[5].toString() : null,
        totalPoints: parseInt(row[6]) || 0,
        totalTasksCompleted: parseInt(row[7]) || 0,
        totalPunishmentsTaken: parseInt(row[8]) || 0,
        registeredAt: row[9] ? row[9].toString() : new Date().toISOString(),
        lastActiveAt: row[10] ? row[10].toString() : new Date().toISOString()
      });
    }

    // Urutkan berdasarkan total points tertinggi
    users.sort(function(a, b) {
      if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
      return b.totalTasksCompleted - a.totalTasksCompleted;
    });

    return jsonResponse({
      status: "success",
      users: users,
      top3: users.slice(0, 3),
      totalUsers: users.length
    });
  }

  // 2. CHECK USERNAME AVAILABILITY
  if (action === "check_username") {
    var checkUsername = (data.username || "").toString().trim().toLowerCase();
    var values = sheet.getDataRange().getValues();
    var isTaken = false;
    
    for (var r = 1; r < values.length; r++) {
      var un = (values[r][1] || "").toString().trim().toLowerCase();
      if (un === checkUsername) {
        isTaken = true;
        break;
      }
    }
    
    return jsonResponse({
      status: "success",
      username: checkUsername,
      isAvailable: !isTaken
    });
  }

  // 3. REGISTER / SYNC SERIOUS USER
  if (action === "register_serious_user" || action === "sync_serious_user") {
    var u = data.user || {};
    var username = (u.username || "").toString().trim();
    var cleanUsername = username.toLowerCase();
    
    if (!username) {
      return jsonResponse({ status: "error", message: "Username tidak boleh kosong" });
    }

    var values = sheet.getDataRange().getValues();
    var foundRowIndex = -1;

    for (var r = 1; r < values.length; r++) {
      var existingUn = (values[r][1] || "").toString().trim().toLowerCase();
      var existingId = (values[r][0] || "").toString().trim();
      if (existingUn === cleanUsername || (u.id && existingId === u.id.toString())) {
        foundRowIndex = r + 1; // 1-based row index
        break;
      }
    }

    if (action === "register_serious_user" && foundRowIndex !== -1) {
      return jsonResponse({
        status: "error",
        code: "USERNAME_EXISTS",
        message: "Username '" + username + "' sudah terdaftar di Google Spreadsheet!"
      });
    }

    var rowData = [
      u.id || ("usr_" + new Date().getTime()),
      username,
      u.password || "",
      u.displayName || username,
      parseInt(u.avatarIndex) || 0,
      u.avatarBase64 || "",
      parseInt(u.totalPoints) || 0,
      parseInt(u.totalTasksCompleted) || 0,
      parseInt(u.totalPunishmentsTaken) || 0,
      u.registeredAt || new Date().toISOString(),
      new Date().toISOString()
    ];

    if (foundRowIndex !== -1) {
      // Update existing user row
      sheet.getRange(foundRowIndex, 1, 1, rowData.length).setValues([rowData]);
      return jsonResponse({
        status: "success",
        action: "updated",
        message: "Data user '" + username + "' berhasil diperbarui di Spreadsheet."
      });
    } else {
      // Append new user row
      sheet.appendRow(rowData);
      return jsonResponse({
        status: "success",
        action: "created",
        message: "Akun user '" + username + "' berhasil didaftarkan di Spreadsheet."
      });
    }
  }

  // 4. GET USER TASKS (FOR MULTI-DEVICE CLOUD SYNC)
  if (action === "get_serious_tasks") {
    var checkUsername = (data.username || (data.user && data.user.username) || "").toString().trim().toLowerCase();
    if (!checkUsername) {
      return jsonResponse({ status: "error", message: "Username wajib disertakan" });
    }
    
    var taskSheetName = "Tasks_Mode_Serius";
    var taskSheet = ss.getSheetByName(taskSheetName);
    if (!taskSheet) {
      return jsonResponse({ status: "success", username: checkUsername, tasks: [] });
    }
    
    var values = taskSheet.getDataRange().getValues();
    var foundTasksJson = "";
    
    for (var r = 1; r < values.length; r++) {
      var un = (values[r][0] || "").toString().trim().toLowerCase();
      if (un === checkUsername) {
        foundTasksJson = values[r][1] ? values[r][1].toString() : "";
        break;
      }
    }
    
    var tasksData = [];
    if (foundTasksJson) {
      try {
        tasksData = JSON.parse(foundTasksJson);
      } catch (e) {
        tasksData = [];
      }
    }
    
    return jsonResponse({
      status: "success",
      username: checkUsername,
      tasks: tasksData,
      rawTasksJson: foundTasksJson
    });
  }

  // 5. SYNC / SAVE USER TASKS (FOR MULTI-DEVICE CLOUD SYNC)
  if (action === "sync_serious_tasks" || action === "save_serious_tasks") {
    var username = (data.username || (data.user && data.user.username) || "").toString().trim();
    var cleanUsername = username.toLowerCase();
    var tasksJson = data.tasksJson || (data.tasks ? JSON.stringify(data.tasks) : "[]");
    
    if (!username) {
      return jsonResponse({ status: "error", message: "Username tidak boleh kosong" });
    }
    
    var taskSheetName = "Tasks_Mode_Serius";
    var taskSheet = ss.getSheetByName(taskSheetName);
    var taskHeaders = ["Username", "Tasks JSON", "Last Updated"];
    
    if (!taskSheet) {
      taskSheet = ss.insertSheet(taskSheetName);
      taskSheet.appendRow(taskHeaders);
      taskSheet.getRange("A1:C1").setFontWeight("bold").setBackground("#1E293B").setFontColor("#F59E0B");
      taskSheet.setFrozenRows(1);
    }
    
    var values = taskSheet.getDataRange().getValues();
    var foundRow = -1;
    
    for (var r = 1; r < values.length; r++) {
      var un = (values[r][0] || "").toString().trim().toLowerCase();
      if (un === cleanUsername) {
        foundRow = r + 1;
        break;
      }
    }
    
    var rowData = [username, tasksJson, new Date().toISOString()];
    
    if (foundRow !== -1) {
      taskSheet.getRange(foundRow, 1, 1, 3).setValues([rowData]);
    } else {
      taskSheet.appendRow(rowData);
    }
    
    return jsonResponse({
      status: "success",
      action: "tasks_synced",
      username: username,
      message: "Daftar task berhasil disinkronkan ke Spreadsheet."
    });
  }

  return null;
}
''';
  }
}

