import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    if (_isInitialized) return;

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

      // Konfigurasi audio context alarm
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

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
          // Fallback ke default jika file kustom tidak ditemukan
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
  static Future<void> _playDefaultAsset(String defaultSound, AudioPlayer player) async {
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

    // Batalkan jadwal lama terlebih dahulu untuk group ini
    await cancelGroupAlarm(group.id);

    // Jika reminder dimatikan atau semua tugas sudah selesai, jangan jadwalkan
    if (!group.reminderEnabled || group.isArchived || group.isAllCompleted) {
      return;
    }

    final targetDate = group.date;
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

    final List<DateTime> triggerTimes = [];

    if (group.reminderType == 'interval') {
      // Mode Interval
      final startParts = _parseTimeString(group.reminderIntervalStartTime);
      final endParts = _parseTimeString(group.reminderIntervalEndTime);

      DateTime currentSlot = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        startParts.$1,
        startParts.$2,
      );

      final endSlot = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        endParts.$1,
        endParts.$2,
      );

      final intervalMins = group.reminderIntervalMinutes.clamp(5, 720);

      while (!currentSlot.isAfter(endSlot)) {
        if (currentSlot.isAfter(now)) {
          triggerTimes.add(currentSlot);
        }
        currentSlot = currentSlot.add(Duration(minutes: intervalMins));
      }
    } else {
      // Mode Specific Times
      for (final timeStr in group.reminderSpecificTimes) {
        final parts = _parseTimeString(timeStr);
        final trigger = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          parts.$1,
          parts.$2,
        );
        if (trigger.isAfter(now)) {
          triggerTimes.add(trigger);
        }
      }
    }

    // Jadwalkan masing-masing waktu
    for (int i = 0; i < triggerTimes.length; i++) {
      final scheduledTime = triggerTimes[i];
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
      final tzScheduled = tz.TZDateTime.from(scheduledDate, loc);

      final pendingTasks = group.pendingItems;
      final pendingCount = pendingTasks.length;
      final previewTasks = pendingTasks.take(3).map((t) => '• ${t.title}').join('\n');
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
        body: '📅 ${group.formattedDateShort}: $pendingCount tugas belum selesai',
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
  static Future<void> cancelGroupAlarm(String groupId) async {
    try {
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
      await _notifications.cancelAll();
      for (final g in groups) {
        if (g.reminderEnabled && !g.isArchived && !g.isAllCompleted) {
          await scheduleGroupAlarm(g);
        }
      }
    } catch (e) {
      debugPrint('Sync all alarms error: $e');
    }
  }
}
