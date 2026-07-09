/// User preferences that shape money display and reporting periods. In M1 these
/// are defaults; the settings screen (M5) makes them editable + persisted.
class AppSettings {
  const AppSettings({
    this.homeCurrency = 'PKR',
    this.currencySymbol = 'Rs ',
    this.monthStartDay = 1,
  });

  final String homeCurrency;
  final String currencySymbol;
  final int monthStartDay;

  AppSettings copyWith({
    String? homeCurrency,
    String? currencySymbol,
    int? monthStartDay,
  }) {
    return AppSettings(
      homeCurrency: homeCurrency ?? this.homeCurrency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      monthStartDay: monthStartDay ?? this.monthStartDay,
    );
  }
}
