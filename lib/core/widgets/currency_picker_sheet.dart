import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Every currency Ledgr offers: (code, symbol, display name).
const kCurrencies = <(String, String, String)>[
  ('PKR', 'Rs ', 'Pakistani Rupee'),
  ('USD', r'$', 'US Dollar'),
  ('EUR', '€', 'Euro'),
  ('GBP', '£', 'British Pound'),
  ('INR', '₹', 'Indian Rupee'),
  ('AED', 'AED ', 'UAE Dirham'),
  ('SAR', 'SR ', 'Saudi Riyal'),
  ('QAR', 'QR ', 'Qatari Riyal'),
  ('KWD', 'KD ', 'Kuwaiti Dinar'),
  ('BHD', 'BD ', 'Bahraini Dinar'),
  ('OMR', 'OMR ', 'Omani Rial'),
  ('TRY', '₺', 'Turkish Lira'),
  ('CAD', r'CA$', 'Canadian Dollar'),
  ('AUD', r'A$', 'Australian Dollar'),
  ('JPY', '¥', 'Japanese Yen'),
  ('CNY', 'CN¥', 'Chinese Yuan'),
  ('MYR', 'RM ', 'Malaysian Ringgit'),
  ('IDR', 'Rp ', 'Indonesian Rupiah'),
  ('BDT', '৳', 'Bangladeshi Taka'),
  ('LKR', 'Rs ', 'Sri Lankan Rupee'),
  ('NPR', 'Rs ', 'Nepalese Rupee'),
  ('AFN', 'Af ', 'Afghan Afghani'),
  ('ZAR', 'R ', 'South African Rand'),
  ('NGN', '₦', 'Nigerian Naira'),
  ('EGP', 'E£', 'Egyptian Pound'),
  ('CHF', 'CHF ', 'Swiss Franc'),
  ('SEK', 'kr ', 'Swedish Krona'),
  ('NOK', 'kr ', 'Norwegian Krone'),
  ('DKK', 'kr ', 'Danish Krone'),
  ('SGD', r'S$', 'Singapore Dollar'),
  ('HKD', r'HK$', 'Hong Kong Dollar'),
  ('KRW', '₩', 'South Korean Won'),
  ('THB', '฿', 'Thai Baht'),
  ('PHP', '₱', 'Philippine Peso'),
  ('VND', '₫', 'Vietnamese Dong'),
  ('BRL', r'R$', 'Brazilian Real'),
  ('MXN', r'MX$', 'Mexican Peso'),
  ('RUB', '₽', 'Russian Ruble'),
];

/// Searchable currency list: filters by code, name, or symbol as you type.
/// Shared by settings and onboarding.
class CurrencyPickerSheet extends StatefulWidget {
  const CurrencyPickerSheet({required this.current, super.key});

  final String current;

  static Future<(String, String, String)?> show(
    BuildContext context, {
    required String current,
  }) {
    return showModalBottomSheet<(String, String, String)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        // Keep the list above the keyboard while searching.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: CurrencyPickerSheet(current: current),
        ),
      ),
    );
  }

  @override
  State<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<CurrencyPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = _query.text.trim().toLowerCase();
    final matches = kCurrencies
        .where(
          (c) =>
              q.isEmpty ||
              c.$1.toLowerCase().contains(q) ||
              c.$3.toLowerCase().contains(q) ||
              c.$2.trim().toLowerCase() == q,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, Gaps.sm),
          child: Text('Currency', style: text.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by code or name',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _query.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: Gaps.sm),
        Expanded(
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    'No currency matches "$q"',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: Gaps.md),
                  children: [
                    for (final c in matches)
                      ListTile(
                        leading: SizedBox(
                          width: 44,
                          child: Text(
                            c.$2.trim(),
                            textAlign: TextAlign.center,
                            style: text.titleSmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        title: Text(c.$3),
                        subtitle: Text(c.$1),
                        trailing: c.$1 == widget.current
                            ? Icon(
                                LucideIcons.circleCheck,
                                color: scheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(c),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
