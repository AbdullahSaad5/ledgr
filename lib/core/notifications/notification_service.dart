import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over local notifications. All calls are guarded so a missing
/// platform plugin (e.g. in tests) degrades to a no-op instead of throwing.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } on Object {
      _ready = false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String channelId = 'ledgr_alerts',
    String channelName = 'Alerts',
  }) async {
    if (!_ready) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
    } on Object {
      // Best-effort: never let a notification failure break a user action.
    }
  }

  /// Schedules a one-shot notification at [when] (local time). Inexact
  /// delivery, so no exact-alarm permission is needed.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String channelId = 'ledgr_reminders',
    String channelName = 'Reminders',
  }) async {
    if (!_ready || when.isBefore(DateTime.now())) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on Object {
      // Best-effort, as above.
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } on Object {
      // Best-effort, as above.
    }
  }
}
