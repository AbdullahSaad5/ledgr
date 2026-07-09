import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper over local notifications. All calls are guarded so a missing
/// platform plugin (e.g. in tests) degrades to a no-op instead of throwing.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
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
}
