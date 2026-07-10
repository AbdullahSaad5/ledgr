import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes dashboard numbers to the Android home-screen widget (#17). The
/// widget reads them from shared preferences via home_widget, so the app just
/// saves and pokes an update — safe to call on every balance change.
abstract final class HomeWidgetSync {
  static Future<void> push({required String netWorth}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.saveWidgetData<String>('net_worth', netWorth);
      await HomeWidget.updateWidget(name: 'LedgrWidgetProvider');
    } on Object {
      // Widget updates are best-effort; never break app flow over them.
    }
  }
}
