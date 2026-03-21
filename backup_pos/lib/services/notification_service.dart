import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/expiration_date.dart';

/// Local notification service — fully offline, no internet needed.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize once at app start
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
  }

  /// Schedule a notification for an expiration date item.
  /// Fires [reminderDays] before the expiry date, at 9:00 AM.
  Future<void> scheduleExpiryNotification({
    required ExpirationDate item,
    required int reminderDays,
  }) async {
    if (!_initialized) await initialize();

    final notifyDate =
        item.expiryDate.subtract(Duration(days: reminderDays));
    final scheduledTime = DateTime(
      notifyDate.year,
      notifyDate.month,
      notifyDate.day,
      9, 0,
    );

    // Don't schedule if the notification time is in the past
    if (scheduledTime.isBefore(DateTime.now())) {
      if (!item.isExpired) {
        await showImmediateNotification(item);
      }
      return;
    }

    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Reminders',
      channelDescription: 'Notifications for product expiration dates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final dateStr =
        '${item.expiryDate.year}-${item.expiryDate.month.toString().padLeft(2, '0')}-${item.expiryDate.day.toString().padLeft(2, '0')}';

    await _plugin.zonedSchedule(
      id: item.id ?? item.barcode.hashCode,
      title: 'Expiring Soon! ⚠️',
      body: '${item.productName ?? item.barcode} expires on $dateStr',
      scheduledDate: tzScheduled,
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Show an immediate notification (for items already expiring soon)
  Future<void> showImmediateNotification(ExpirationDate item) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Reminders',
      channelDescription: 'Notifications for product expiration dates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final days = item.daysRemaining;
    final String body;
    if (days < 0) {
      body =
          '${item.productName ?? item.barcode} expired ${-days} days ago!';
    } else if (days == 0) {
      body = '${item.productName ?? item.barcode} expires TODAY!';
    } else {
      body =
          '${item.productName ?? item.barcode} expires in $days days';
    }

    await _plugin.show(
      id: item.id ?? item.barcode.hashCode,
      title: days < 0 ? 'Expired! 🔴' : 'Expiring Soon! ⚠️',
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// Re-schedule all notifications based on current expiry data
  Future<void> rescheduleAll({
    required List<ExpirationDate> items,
    required int reminderDays,
  }) async {
    await cancelAllNotifications();
    for (final item in items) {
      if (!item.isExpired) {
        await scheduleExpiryNotification(
          item: item,
          reminderDays: reminderDays,
        );
      }
    }
  }
}
