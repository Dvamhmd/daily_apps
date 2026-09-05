import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AlarmTriggerPayload {
  final String groupId;
  final DateTime date;
  final String soundType;
  final String defaultSound;
  final String? customSoundPath;
  final String? customSoundName;

  AlarmTriggerPayload({
    required this.groupId,
    required this.date,
    required this.soundType,
    required this.defaultSound,
    this.customSoundPath,
    this.customSoundName,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'date': date.toIso8601String(),
        'soundType': soundType,
        'defaultSound': defaultSound,
        'customSoundPath': customSoundPath,
        'customSoundName': customSoundName,
      };

  factory AlarmTriggerPayload.fromJson(Map<String, dynamic> json) {
    return AlarmTriggerPayload(
      groupId: json['groupId'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      soundType: json['soundType'] as String? ?? 'default',
      defaultSound: json['defaultSound'] as String? ?? 'chime_classic',
      customSoundPath: json['customSoundPath'] as String?,
      customSoundName: json['customSoundName'] as String?,
    );
  }
}

@pragma('vm:entry-point')
void todoAlarmBackgroundNotificationResponseHandler(NotificationResponse resp) {
  if (resp.actionId == 'action_dismiss') {
    TodoAlarmService.stopAlarmSound();
  }
}

class TodoAlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _alarmPlayer = AudioPlayer();
  static final AudioPlayer _previewPlayer = AudioPlayer();

  static bool _isInitialized = false;
  static bool _isPlayingAlarm = false;
  static Timer? _timeoutTimer;
  static Timer? _foregroundTicker;
  static Timer? _vibrationTimer;

  static final Map<String, TodoDateGroup> _registeredGroups = {};
  static final Set<String> _triggeredKeys = {};

  static Function(AlarmTriggerPayload payload)? _onNotificationClickCallback;

  static final ValueNotifier<AlarmTriggerPayload?> activeAlarmNotifier =
      ValueNotifier<AlarmTriggerPayload?>(null);

  static const String _channelId = 'todo_reminder_alarm_channel_v3';
  static const String _channelName = 'Pengingat Alarm To-Do List';
  static const String _channelDesc =
      'Alarm pengingat tugas to-do list yang belum selesai dengan suara looping, getar, dan layar penuh.';

  static bool get isPlayingAlarm => _isPlayingAlarm;

  /// Inisialisasi Service Notifikasi & Audio Player
  static Future<void> initialize({
    Function(AlarmTriggerPayload payload)? onNotificationClick,
  }) async {
    if (onNotificationClick != null) {
      _onNotificationClickCallback = onNotificationClick;
    }

    if (_isInitialized) {
      _startForegroundTicker();
      return;
    }

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
        } catch (_) {}
      }

      if (!kIsWeb) {
        const androidSettings =
            AndroidInitializationSettings('@mipmap/launcher_icon');
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _notifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse resp) async {
            if (resp.actionId == 'action_dismiss') {
              await stopAlarmSound();
              return;
            }
            final payloadStr = resp.payload;
            if (payloadStr != null && payloadStr.isNotEmpty) {
              try {
                final data = jsonDecode(payloadStr);
                final payload = AlarmTriggerPayload.fromJson(data);
                final triggered = await _handleAlarmTrigger(payload);
                if (triggered) {
                  _onNotificationClickCallback?.call(payload);
                }
              } catch (e) {
                debugPrint('Error parsing notification payload: $e');
              }
            }
          },
          onDidReceiveBackgroundNotificationResponse:
              todoAlarmBackgroundNotificationResponseHandler,
        );

        // Cek apakah aplikasi dibuka langsung dari Full Screen Intent / Notifikasi Alarm saat mati/tertutup
        try {
          final launchDetails =
              await _notifications.getNotificationAppLaunchDetails();
          if (launchDetails != null &&
              launchDetails.didNotificationLaunchApp &&
              launchDetails.notificationResponse != null) {
            final payloadStr = launchDetails.notificationResponse!.payload;
            if (payloadStr != null && payloadStr.isNotEmpty) {
              final data = jsonDecode(payloadStr);
              final payload = AlarmTriggerPayload.fromJson(data);
              Future.delayed(const Duration(milliseconds: 600), () async {
                final triggered = await _handleAlarmTrigger(payload);
                if (triggered) {
                  _onNotificationClickCallback?.call(payload);
                }
              });
            }
          }
        } catch (e) {
          debugPrint('Error checking notification launch details: $e');
        }

        // Buat Android Notification Channel dengan prioritas tertinggi untuk Alarm
        try {
          final androidPlatform = _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          if (androidPlatform != null) {
            final alarmChannel = AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              vibrationPattern:
                  Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
              enableLights: true,
              showBadge: true,
            );
            await androidPlatform.createNotificationChannel(alarmChannel);
          }
        } catch (e) {
          debugPrint('Error creating Android notification channel: $e');
        }
      }

      // Konfigurasi audio context alarm
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

      if (!kIsWeb && Platform.isAndroid) {
        // Listener MethodChannel dari native Android (AlarmReceiver / AlarmActionReceiver / MainActivity)
        _nativeChannel.setMethodCallHandler((call) async {
          debugPrint('🔔 [NATIVE CHANNEL CALL]: ${call.method}');
          if (call.method == 'onAlarmTriggered') {
            final payloadStr = call.arguments as String?;
            if (payloadStr != null && payloadStr.isNotEmpty) {
              try {
                final data = jsonDecode(payloadStr);
                final payload = AlarmTriggerPayload.fromJson(data);
                final triggered = await _handleAlarmTrigger(payload);
                if (triggered) {
                  _onNotificationClickCallback?.call(payload);
                }
              } catch (e) {
                debugPrint('Error parsing native onAlarmTriggered payload: $e');
              }
            }
          } else if (call.method == 'onAlarmDismissed') {
            await stopAlarmSound();
          }
        });

        // Cek apakah aplikasi baru saja dibuka/dinyalakan oleh native AlarmReceiver
        try {
          final initialPayloadStr =
              await _nativeChannel.invokeMethod<String>('getInitialAlarmPayload');
          if (initialPayloadStr != null && initialPayloadStr.isNotEmpty) {
            debugPrint('🔔 [COLD START ALARM PAYLOAD DETECTED]');
            final data = jsonDecode(initialPayloadStr);
            final payload = AlarmTriggerPayload.fromJson(data);
            Future.delayed(const Duration(milliseconds: 400), () async {
              final triggered = await _handleAlarmTrigger(payload);
              if (triggered) {
                _onNotificationClickCallback?.call(payload);
              }
            });
          }
        } catch (e) {
          debugPrint('Error checking native initial alarm payload: $e');
        }
      }

      _startForegroundTicker();

      _isInitialized = true;
    } catch (e) {
      debugPrint('TodoAlarmService initialize error: $e');
    }
  }

  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.daily_apps/alarm_permissions');

  /// Bawa aplikasi ke layar depan saat alarm berbunyi jika izin overlay aktif
  static Future<void> bringAppToForeground() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _nativeChannel.invokeMethod('bringAppToForeground');
      }
    } catch (e) {
      debugPrint('Error bringing app to foreground: $e');
    }
  }

  /// Cek apakah izin Full Screen Intent aktif di Android 14+
  static Future<bool> canUseFullScreenIntent() async {
    try {
      if (kIsWeb || !Platform.isAndroid) return true;
      final bool? granted =
          await _nativeChannel.invokeMethod<bool>('canUseFullScreenIntent');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Buka pengaturan Full Screen Intent di Android 14+
  static Future<void> openFullScreenIntentSettings() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _nativeChannel.invokeMethod('openFullScreenIntentSettings');
      }
    } catch (e) {
      debugPrint('Error opening full screen intent settings: $e');
    }
  }

  /// Cek apakah izin overlay ("Tampilkan di atas aplikasi lain") sudah aktif
  static Future<bool> isOverlayPermissionGranted() async {
    try {
      if (kIsWeb || !Platform.isAndroid) return true;
      final bool? granted =
          await _nativeChannel.invokeMethod<bool>('canDrawOverlays');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Buka pengaturan izin overlay di Android
  static Future<void> openOverlaySettings() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _nativeChannel.invokeMethod('openOverlaySettings');
      }
    } catch (e) {
      debugPrint('Error opening overlay settings: $e');
    }
  }

  /// Buka pengaturan izin alarm presisi di Android 12+
  static Future<void> openExactAlarmSettings() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _nativeChannel.invokeMethod('openExactAlarmSettings');
      }
    } catch (e) {
      debugPrint('Error opening exact alarm settings: $e');
    }
  }

  /// Dialog konfirmasi permintaan izin Tampilkan di Atas Aplikasi Lain
  static Future<bool> requestOverlayPermissionWithDialog(
      BuildContext context) async {
    if (kIsWeb) return true;
    final bool isGranted = await isOverlayPermissionGranted();
    if (isGranted) return true;

    if (!context.mounted) return false;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.layers_rounded, color: Color(0xFFBA5A3A), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Izin Tampil di Layar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Agar pop-up pengingat tugas dapat otomatis muncul di atas layar saat HP terkunci atau saat membuka aplikasi lain, mohon aktifkan izin "Tampilkan di atas aplikasi lain" untuk Daily Apps.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Nanti Saja',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx, true);
                await openOverlaySettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA5A3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Buka Pengaturan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Request permissions untuk Android 13+ & Alarm & Notifications
  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      final androidPlatform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
        await androidPlatform.requestExactAlarmsPermission();
      }

      final iosPlatform = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Request permissions error: $e');
    }
  }

  /// Memicu pop-up alarm dan suara seketika untuk keperluan testing / demo (mendukung Chrome & Web)
  static Future<void> triggerTestAlarm({
    required TodoDateGroup group,
    String? soundType,
    String? defaultSound,
    String? customPath,
    String? customName,
  }) async {
    await initialize();
    final payload = AlarmTriggerPayload(
      groupId: group.id,
      date: group.date,
      soundType: soundType ?? group.reminderSoundType,
      defaultSound: defaultSound ?? group.reminderDefaultSound,
      customSoundPath: customPath ?? group.reminderCustomSoundPath,
      customSoundName: customName ?? group.reminderCustomSoundName,
    );
    await _handleAlarmTrigger(payload);
    _onNotificationClickCallback?.call(payload);
  }

  /// Real-time Ticker internal untuk memantau alarm saat aplikasi terbuka (foreground)
  static void _startForegroundTicker() {
    _foregroundTicker?.cancel();
    _foregroundTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final group in _registeredGroups.values) {
        if (!group.reminderEnabled || group.isArchived || group.isAllCompleted) {
          continue;
        }

        // Jika section tanggal sudah terlewati (sebelum hari ini), lewati alarm
        final localGroupDate = group.date.toLocal();
        final groupDate =
            DateTime(localGroupDate.year, localGroupDate.month, localGroupDate.day);
        if (groupDate.isBefore(today)) {
          continue;
        }

        final pendingItems = group.items.where((i) => !i.isCompleted).toList();
        if (pendingItems.isEmpty) continue;

        final targetTimes = _getScheduledTriggerTimes(group, now);
        for (final target in targetTimes) {
          final isSameDay = now.year == target.year &&
              now.month == target.month &&
              now.day == target.day;
          final isSameMinute =
              now.hour == target.hour && now.minute == target.minute;

          if (isSameDay && isSameMinute) {
            final key =
                '${group.id}_${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}';
            if (!_triggeredKeys.contains(key)) {
              _triggeredKeys.add(key);
              debugPrint(
                  '🔔 [FOREGROUND ALARM TRIGGERED] Group: ${group.id} at ${now.hour}:${now.minute.toString().padLeft(2, '0')}');

              final payload = AlarmTriggerPayload(
                groupId: group.id,
                date: group.date,
                soundType: group.reminderSoundType,
                defaultSound: group.reminderDefaultSound,
                customSoundPath: group.reminderCustomSoundPath,
                customSoundName: group.reminderCustomSoundName,
              );
              _handleAlarmTrigger(payload);
            }
          }
        }
      }
    });
  }

  /// Helper untuk menghitung seluruh waktu trigger aktif untuk sebuah group
  static List<DateTime> _getScheduledTriggerTimes(
      TodoDateGroup group, DateTime now) {
    final List<DateTime> times = [];
    final today = DateTime(now.year, now.month, now.day);
    final localGroupDate = group.date.toLocal();
    final groupDate =
        DateTime(localGroupDate.year, localGroupDate.month, localGroupDate.day);

    // Jika tanggal section sudah lewat dari hari ini, tidak ada jadwal waktu aktif lagi
    if (groupDate.isBefore(today)) {
      return times;
    }

    final baseDate = groupDate;

    if (group.reminderType == 'interval') {
      final startParts = _parseTimeString(group.reminderIntervalStartTime);
      final endParts = _parseTimeString(group.reminderIntervalEndTime);

      DateTime currentSlot = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        startParts.$1,
        startParts.$2,
      );

      final endSlot = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        endParts.$1,
        endParts.$2,
      );

      final intervalMins = group.reminderIntervalMinutes.clamp(1, 720);

      while (!currentSlot.isAfter(endSlot)) {
        times.add(currentSlot);
        currentSlot = currentSlot.add(Duration(minutes: intervalMins));
      }
    } else {
      for (final timeStr in group.reminderSpecificTimes) {
        final parts = _parseTimeString(timeStr);
        final trigger = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          parts.$1,
          parts.$2,
        );
        times.add(trigger);
      }
    }

    return times;
  }

  /// Trigger internal saat alarm aktif (mengembalikan false jika diabaikan)
  static Future<bool> _handleAlarmTrigger(AlarmTriggerPayload payload) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localPayloadDate = payload.date.toLocal();
    final payloadDate =
        DateTime(localPayloadDate.year, localPayloadDate.month, localPayloadDate.day);

    // Jika section tanggal sudah terlewati (sebelum hari ini), jangan bunyikan alarm
    if (payloadDate.isBefore(today)) {
      debugPrint(
          '⚠️ [ALARM IGNORED] Section date is in the past: ${payload.date}');
      await stopAlarmSound();
      return false;
    }

    final group = _registeredGroups[payload.groupId];
    if (group != null) {
      final localGroupDate = group.date.toLocal();
      final groupDate =
          DateTime(localGroupDate.year, localGroupDate.month, localGroupDate.day);
      if (!group.reminderEnabled ||
          group.isArchived ||
          group.isAllCompleted ||
          groupDate.isBefore(today)) {
        debugPrint(
            '⚠️ [ALARM IGNORED] Group ${group.id} is archived, all completed, past date, or reminder disabled');
        await stopAlarmSound();
        return false;
      }
    }

    // Tarik aplikasi ke layar depan jika izin overlay aktif
    await bringAppToForeground();
    activeAlarmNotifier.value = payload;
    await playAlarmSound(
      soundType: payload.soundType,
      defaultSound: payload.defaultSound,
      customPath: payload.customSoundPath,
    );
    return true;
  }

  /// Mainkan suara alarm secara looping (maks 5 menit)
  static Future<void> playAlarmSound({
    required String soundType,
    String defaultSound = 'chime_classic',
    String? customPath,
  }) async {
    try {
      await stopAlarmSound();
      _isPlayingAlarm = true;

      // Konfigurasi audio context ke stream ALARM sistem Android (mengikuti slider volume Alarm sistem & aturan DND/Jangan Ganggu)
      try {
        await _alarmPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransientExclusive,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
          ),
        );
      } catch (e) {
        debugPrint('Audio context config error (ignorable on web/desktop): $e');
      }

      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

      if (soundType == 'custom' && customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);
        if (await file.exists()) {
          await _alarmPlayer.play(DeviceFileSource(customPath));
        } else {
          await _playDefaultAsset(defaultSound, _alarmPlayer);
        }
      } else {
        await _playDefaultAsset(defaultSound, _alarmPlayer);
      }

      // Mulai getaran berulang di Android (Native Vibrator) & HapticFeedback
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _nativeChannel.invokeMethod('startVibration');
        } catch (e) {
          debugPrint('Error starting native vibration: $e');
        }
      }

      _vibrationTimer?.cancel();
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
        try {
          HapticFeedback.vibrate();
        } catch (_) {}
      });

      // Pasang timeout 5 menit untuk otomatis berhenti jika pengguna tidak merespons
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(minutes: 5), () {
        debugPrint('Alarm 5-minute timeout reached. Stopping sound.');
        stopAlarmSound();
      });
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  /// Helper memutar aset nada dering default
  static Future<void> _playDefaultAsset(
      String defaultSound, AudioPlayer player) async {
    String assetFile;
    switch (defaultSound) {
      case 'alarm_digital':
        assetFile = 'sounds/alarm_digital.wav';
        break;
      case 'gentle_bell':
        assetFile = 'sounds/gentle_bell.wav';
        break;
      case 'cheerful_melody':
        assetFile = 'sounds/cheerful_melody.wav';
        break;
      case 'chime_classic':
      default:
        assetFile = 'sounds/chime_classic.wav';
        break;
    }
    await player.play(AssetSource(assetFile));
  }

  /// Hentikan suara alarm & getaran serta batalkan timeout 5 menit
  static Future<void> stopAlarmSound() async {
    try {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      _isPlayingAlarm = false;

      // Hentikan getaran native Android
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _nativeChannel.invokeMethod('stopVibration');
        } catch (e) {
          debugPrint('Error stopping native vibration: $e');
        }
      }

      await _alarmPlayer.stop();
      activeAlarmNotifier.value = null;
    } catch (e) {
      debugPrint('Error stopping alarm sound: $e');
    }
  }

  /// Preview suara saat memilih nada dering di halaman setup (mengikuti stream Media)
  static Future<void> playPreview({
    required String soundType,
    String defaultSound = 'chime_classic',
    String? customPath,
  }) async {
    try {
      await stopPreview();

      try {
        await _previewPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {
                AVAudioSessionOptions.duckOthers,
              },
            ),
          ),
        );
      } catch (_) {}

      await _previewPlayer.setReleaseMode(ReleaseMode.stop);

      if (soundType == 'custom' && customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);
        if (await file.exists()) {
          await _previewPlayer.play(DeviceFileSource(customPath));
        } else {
          await _playDefaultAsset(defaultSound, _previewPlayer);
        }
      } else {
        await _playDefaultAsset(defaultSound, _previewPlayer);
      }
    } catch (e) {
      debugPrint('Error playing sound preview: $e');
    }
  }

  /// Hentikan preview suara
  static Future<void> stopPreview() async {
    try {
      await _previewPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping sound preview: $e');
    }
  }

  /// Jadwalkan seluruh alarm untuk sebuah TodoDateGroup
  static Future<void> scheduleGroupAlarm(TodoDateGroup group) async {
    await initialize();

    // Daftarkan group ke memori internal
    _registeredGroups[group.id] = group;

    // Batalkan jadwal lama terlebih dahulu untuk group ini
    await cancelGroupAlarm(group.id, unregister: false);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localGroupDate = group.date.toLocal();
    final groupDate =
        DateTime(localGroupDate.year, localGroupDate.month, localGroupDate.day);

    // Jika reminder dimatikan, semua tugas sudah selesai, atau tanggal section sudah terlewati, batalkan dan jangan jadwalkan
    if (!group.reminderEnabled ||
        group.isArchived ||
        group.isAllCompleted ||
        groupDate.isBefore(today)) {
      await cancelGroupAlarm(group.id, unregister: false);
      return;
    }

    final payload = AlarmTriggerPayload(
      groupId: group.id,
      date: group.date,
      soundType: group.reminderSoundType,
      defaultSound: group.reminderDefaultSound,
      customSoundPath: group.reminderCustomSoundPath,
      customSoundName: group.reminderCustomSoundName,
    );
    final payloadJson = jsonEncode(payload.toJson());

    final allTriggerTimes = _getScheduledTriggerTimes(group, now);
    final futureTriggerTimes =
        allTriggerTimes.where((t) => t.isAfter(now)).toList();

    // Jadwalkan masing-masing waktu ke OS notification
    for (int i = 0; i < futureTriggerTimes.length; i++) {
      final scheduledTime = futureTriggerTimes[i];
      final notifId = _generateNotificationId(group.id, i);

      await _scheduleSingleNotification(
        id: notifId,
        group: group,
        scheduledDate: scheduledTime,
        payload: payloadJson,
      );
    }
  }

  static (int, int) _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final h = int.parse(parts[0].trim());
      final m = int.parse(parts[1].trim());
      return (h.clamp(0, 23), m.clamp(0, 59));
    } catch (_) {
      return (8, 0);
    }
  }

  static int _generateNotificationId(String groupId, int index) {
    final hash = groupId.hashCode.abs() % 50000;
    return hash * 10 + (index % 10);
  }

  static Future<void> _scheduleSingleNotification({
    required int id,
    required TodoDateGroup group,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    try {
      // Jadwalkan langsung ke native Android AlarmManager untuk memicu getaran dan membuka pop-up alarm tanpa notifikasi sistem berisik
      if (!kIsWeb && Platform.isAndroid) {
        await _nativeChannel.invokeMethod('scheduleNativeAlarm', {
          'id': id,
          'timeMillis': scheduledDate.millisecondsSinceEpoch,
          'payload': payload,
          'title': '🚨 Tugasmu belum selesai nih',
          'body':
              '📅 ${group.formattedDateShort}: ${group.pendingItems.length} tugas belum selesai',
        });
      }
    } catch (e) {
      debugPrint('Schedule native todo alarm error: $e');
    }
  }

  /// Batalkan semua alarm untuk group ID tertentu (maks 10 slot)
  static Future<void> cancelGroupAlarm(String groupId,
      {bool unregister = true}) async {
    try {
      if (unregister) {
        _registeredGroups.remove(groupId);
      }
      final baseHash = groupId.hashCode.abs() % 50000;
      for (int i = 0; i < 10; i++) {
        final notifId = baseHash * 10 + i;
        if (!kIsWeb) {
          await _notifications.cancel(id: notifId);
        }
        if (!kIsWeb && Platform.isAndroid) {
          try {
            await _nativeChannel.invokeMethod('cancelNativeAlarm', {
              'id': notifId,
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Cancel group alarm error: $e');
    }
  }

  /// Sinkronisasi ulang semua alarm dari seluruh group aktif
  static Future<void> syncAllAlarms(List<TodoDateGroup> groups) async {
    try {
      _registeredGroups.clear();
      if (!kIsWeb) {
        await _notifications.cancelAll();
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final g in groups) {
        _registeredGroups[g.id] = g;
        final localGroupDate = g.date.toLocal();
        final groupDate = DateTime(localGroupDate.year, localGroupDate.month, localGroupDate.day);
        if (g.reminderEnabled &&
            !g.isArchived &&
            !g.isAllCompleted &&
            !groupDate.isBefore(today)) {
          await scheduleGroupAlarm(g);
        } else {
          // Batalkan alarm untuk group yang sudah lewat / selesai / nonaktif
          await cancelGroupAlarm(g.id, unregister: false);
        }
      }
    } catch (e) {
      debugPrint('Sync all alarms error: $e');
    }
  }
}
