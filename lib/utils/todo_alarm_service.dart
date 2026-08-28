import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:flutter/foundation.dart';
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

class TodoAlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _alarmPlayer = AudioPlayer();
  static final AudioPlayer _previewPlayer = AudioPlayer();

  static bool _isInitialized = false;
  static bool _isPlayingAlarm = false;
  static Timer? _timeoutTimer;
  static Timer? _foregroundTicker;

  static final Map<String, TodoDateGroup> _registeredGroups = {};
  static final Set<String> _triggeredKeys = {};

  static final ValueNotifier<AlarmTriggerPayload?> activeAlarmNotifier =
      ValueNotifier<AlarmTriggerPayload?>(null);

  static const String _channelId = 'todo_reminder_alarm_channel_v2';
  static const String _channelName = 'Pengingat Alarm To-Do List';
  static const String _channelDesc =
      'Alarm pengingat tugas to-do list yang belum selesai dengan suara looping dan layar penuh.';

  static bool get isPlayingAlarm => _isPlayingAlarm;

  /// Inisialisasi Service Notifikasi & Audio Player
  static Future<void> initialize({
    Function(AlarmTriggerPayload payload)? onNotificationClick,
  }) async {
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
        onDidReceiveNotificationResponse: (NotificationResponse resp) {
          final payloadStr = resp.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final data = jsonDecode(payloadStr);
              final payload = AlarmTriggerPayload.fromJson(data);
              _handleAlarmTrigger(payload);
              onNotificationClick?.call(payload);
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Buat Android Notification Channel dengan prioritas tertinggi untuk Alarm
      try {
        final androidPlatform = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlatform != null) {
          const alarmChannel = AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
          );
          await androidPlatform.createNotificationChannel(alarmChannel);
        }
      } catch (e) {
        debugPrint('Error creating Android notification channel: $e');
      }

      // Konfigurasi audio context alarm
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

      _startForegroundTicker();

      _isInitialized = true;
    } catch (e) {
      debugPrint('TodoAlarmService initialize error: $e');
    }
  }

  /// Request permissions untuk Android 13+ & Alarm
  static Future<void> requestPermissions() async {
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

  /// Real-time Ticker internal untuk memantau alarm saat aplikasi terbuka (foreground)
  static void _startForegroundTicker() {
    _foregroundTicker?.cancel();
    _foregroundTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();

      for (final group in _registeredGroups.values) {
        if (!group.reminderEnabled || group.isArchived || group.isAllCompleted) {
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
    final groupDate =
        DateTime(group.date.year, group.date.month, group.date.day);

    final baseDate = groupDate.isBefore(today) ? today : groupDate;

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

  /// Trigger internal saat alarm aktif
  static Future<void> _handleAlarmTrigger(AlarmTriggerPayload payload) async {
    activeAlarmNotifier.value = payload;
    await playAlarmSound(
      soundType: payload.soundType,
      defaultSound: payload.defaultSound,
      customPath: payload.customSoundPath,
    );
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

      // Konfigurasi audio context ke alarm/speaker
      try {
        await _alarmPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
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

  /// Hentikan suara alarm & batalkan timeout 5 menit
  static Future<void> stopAlarmSound() async {
    try {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _isPlayingAlarm = false;
      await _alarmPlayer.stop();
      activeAlarmNotifier.value = null;
    } catch (e) {
      debugPrint('Error stopping alarm sound: $e');
    }
  }

  /// Preview suara saat memilih nada dering di halaman setup
  static Future<void> playPreview({
    required String soundType,
    String defaultSound = 'chime_classic',
    String? customPath,
  }) async {
    try {
      await stopPreview();
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

    // Jika reminder dimatikan atau semua tugas sudah selesai, jangan jadwalkan
    if (!group.reminderEnabled || group.isArchived || group.isAllCompleted) {
      return;
    }

    final now = DateTime.now();
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
      tz.Location loc;
      try {
        loc = tz.local;
      } catch (_) {
        loc = tz.UTC;
      }

      tz.TZDateTime tzScheduled;
      try {
        tzScheduled = tz.TZDateTime(
          loc,
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledDate.hour,
          scheduledDate.minute,
        );
      } catch (_) {
        tzScheduled = tz.TZDateTime.from(scheduledDate, loc);
      }

      final pendingTasks = group.pendingItems;
      final pendingCount = pendingTasks.length;
      final previewTasks =
          pendingTasks.take(3).map((t) => '• ${t.title}').join('\n');
      final taskSummary = pendingCount > 3
          ? '$previewTasks\n...dan ${pendingCount - 3} tugas lainnya'
          : previewTasks.isNotEmpty
              ? previewTasks
              : 'Ada tugas yang belum selesai!';

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        styleInformation: BigTextStyleInformation(
          '📅 ${group.formattedFullDate}\n\n$taskSummary',
          contentTitle: '🚨 Tugasmu ada yang belum selesai Nih',
          summaryText: '$pendingCount tugas belum selesai',
        ),
        actions: const [
          AndroidNotificationAction(
            'action_dismiss',
            'Iyaa tau',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'action_view',
            'Buka To-Do',
            showsUserInterface: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id: id,
        title: '🚨 Tugasmu ada yang belum selesai Nih',
        body:
            '📅 ${group.formattedDateShort}: $pendingCount tugas belum selesai',
        scheduledDate: tzScheduled,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Schedule single todo alarm error: $e');
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
        await _notifications.cancel(id: baseHash * 10 + i);
      }
    } catch (e) {
      debugPrint('Cancel group alarm error: $e');
    }
  }

  /// Sinkronisasi ulang semua alarm dari seluruh group aktif
  static Future<void> syncAllAlarms(List<TodoDateGroup> groups) async {
    try {
      _registeredGroups.clear();
      await _notifications.cancelAll();
      for (final g in groups) {
        _registeredGroups[g.id] = g;
        if (g.reminderEnabled && !g.isArchived && !g.isAllCompleted) {
          await scheduleGroupAlarm(g);
        }
      }
    } catch (e) {
      debugPrint('Sync all alarms error: $e');
    }
  }
}
