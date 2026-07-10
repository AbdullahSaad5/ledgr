import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes dashboard numbers to the Android home-screen widgets (#17). The
/// widgets read them from shared preferences via home_widget, so the app just
/// saves and pokes an update — safe to call on every balance change.
abstract final class HomeWidgetSync {
  static Future<void> push({
    required String netWorth,
    required String periodLabel,
    required String spent,
    required String received,
    required String todaySpent,
    String? budgetLabel,
    int budgetPct = -1,
    String tx1Title = '',
    String tx1Amount = '',
    String tx2Title = '',
    String tx2Amount = '',
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.saveWidgetData<String>('net_worth', netWorth);
      await HomeWidget.saveWidgetData<String>('period_label', periodLabel);
      await HomeWidget.saveWidgetData<String>('spent', spent);
      await HomeWidget.saveWidgetData<String>('received', received);
      await HomeWidget.saveWidgetData<String>('today_spent', todaySpent);
      await HomeWidget.saveWidgetData<String>(
        'budget_label',
        budgetLabel ?? '',
      );
      await HomeWidget.saveWidgetData<int>('budget_pct', budgetPct);
      await HomeWidget.saveWidgetData<String>('tx1_title', tx1Title);
      await HomeWidget.saveWidgetData<String>('tx1_amount', tx1Amount);
      await HomeWidget.saveWidgetData<String>('tx2_title', tx2Title);
      await HomeWidget.saveWidgetData<String>('tx2_amount', tx2Amount);
      await HomeWidget.updateWidget(name: 'LedgrWidgetProvider');
      await HomeWidget.updateWidget(name: 'LedgrQuickAddWidgetProvider');
    } on Object {
      // Widget updates are best-effort; never break app flow over them.
    }
  }
}
