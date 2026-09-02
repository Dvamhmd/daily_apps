import 'package:daily_apps/models/model_tagihan.dart';
import 'package:daily_apps/utils/rupiah_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
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

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(settings: settings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  /// Request permission explicitly for Android 13+ and iOS
  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      final androidPlatform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
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
      debugPrint('Request notification permissions error: $e');
    }
  }

  /// Menjadwalkan pengingat deadline untuk satu tagihan (H-3 dan H-1)
  static Future<void> jadwalkanTagihan(Tagihan tagihan) async {
    if (tagihan.deadline == null) return;
    await initialize();

    final deadline = tagihan.deadline!;
    final now = DateTime.now();

    // Hash unik untuk ID notifikasi berdasarkan nama tagihan
    final baseId = tagihan.nama.hashCode.abs() % 100000;

    // H-3 Reminder
    final h3Date = DateTime(deadline.year, deadline.month, deadline.day - 3, 9, 0);
    if (h3Date.isAfter(now)) {
      await _scheduleSingle(
        id: baseId * 2,
        title: '🔔 Tagihan Segera Jatuh Tempo (H-3)',
        body:
            'Tagihan "${tagihan.nama}" sebesar ${RupiahFormatter.format(tagihan.jumlah)} jatuh tempo dalam 3 hari.',
        scheduledDate: h3Date,
      );
    }

    // H-1 Reminder
    final h1Date = DateTime(deadline.year, deadline.month, deadline.day - 1, 9, 0);
    if (h1Date.isAfter(now)) {
      await _scheduleSingle(
        id: baseId * 2 + 1,
        title: '⚠️ Pengingat: Tagihan Besok Jatuh Tempo (H-1)',
        body:
            'Jangan lupa bayar "${tagihan.nama}" sebesar ${RupiahFormatter.format(tagihan.jumlah)} besok!',
        scheduledDate: h1Date,
      );
    }
  }

  static Future<void> _scheduleSingle({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      tz.Location loc;
      try {
        loc = tz.local;
      } catch (_) {
        loc = tz.UTC;
      }
      final tzScheduled = tz.TZDateTime.from(scheduledDate, loc);

      const androidDetails = AndroidNotificationDetails(
        'tagihan_deadline_channel',
        'Pengingat Deadline Tagihan',
        channelDescription:
            'Notifikasi pengingat sebelum tagihan jatuh tempo (H-3 dan H-1)',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  /// Membatalkan notifikasi saat tagihan dihapus atau dibayar
  static Future<void> batalkanTagihan(Tagihan tagihan) async {
    try {
      final baseId = tagihan.nama.hashCode.abs() % 100000;
      await _notifications.cancel(id: baseId * 2);
      await _notifications.cancel(id: baseId * 2 + 1);
    } catch (e) {
      debugPrint('Cancel notification error: $e');
    }
  }

  /// Menjadwalkan ulang semua notifikasi untuk seluruh tagihan yang belum lunas
  static Future<void> jadwalkanUlangSemua(List<Tagihan> list) async {
    try {
      await _notifications.cancelAll();
      for (final t in list) {
        if (t.deadline != null) {
          await jadwalkanTagihan(t);
        }
      }
    } catch (e) {
      debugPrint('Reschedule all notifications error: $e');
    }
  }
}
