import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/settings/app_settings.dart';
import 'package:ledgr/core/time/period_resolver.dart';

/// Current settings. Overridable in tests; made persistent + editable in M5.
final appSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return MoneyFormatter(symbol: settings.currencySymbol);
});

final periodResolverProvider = Provider<PeriodResolver>(
  (ref) => PeriodResolver(ref.watch(appSettingsProvider).monthStartDay),
);
