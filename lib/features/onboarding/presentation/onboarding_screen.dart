import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _currencies = <(String, String)>[
  ('PKR', 'Rs '),
  ('USD', r'$'),
  ('EUR', '€'),
  ('GBP', '£'),
  ('INR', '₹'),
  ('AED', 'AED '),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    _cash.dispose();
    _bank.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = ref.read(appSettingsProvider);
    final accounts = ref.read(accountRepositoryProvider);
    final currency = settings.homeCurrency;
    if (_cash.text.trim().isNotEmpty || _page >= 2) {
      await accounts.create(
        name: 'Cash',
        type: AccountType.cash,
        icon: 'payments',
        color: 0xFF43A047,
        currency: currency,
        openingBalanceMinor: MoneyField.parse(_cash.text, currency).minor,
      );
    }
    if (_bank.text.trim().isNotEmpty) {
      await accounts.create(
        name: 'Bank',
        type: AccountType.bank,
        icon: 'account_balance',
        color: 0xFF1565C0,
        currency: currency,
        openingBalanceMinor: MoneyField.parse(_bank.text, currency).minor,
      );
    }
    await ref.read(settingsControllerProvider.notifier).setOnboardingComplete();
  }

  Future<void> _skip() async {
    await ref.read(settingsControllerProvider.notifier).setOnboardingComplete();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: _skip, child: const Text('Skip'))],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _WelcomePage(),
                _CurrencyPage(
                  selected: settings.homeCurrency,
                  onSelect: (code, symbol) => ref
                      .read(settingsControllerProvider.notifier)
                      .setCurrency(code, symbol),
                ),
                _AccountsPage(
                  cash: _cash,
                  bank: _bank,
                  currency: settings.homeCurrency,
                  symbol: settings.currencySymbol,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
                FilledButton(
                  onPressed: _page == 2
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                  child: Text(_page == 2 ? 'Get started' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LedgrLogoMark(size: 84),
          const SizedBox(height: 24),
          Text(
            'Welcome to Ledgr',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Track every account, capture expenses in seconds, and see where '
            'your money goes. Everything stays on your phone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage({required this.selected, required this.onSelect});

  final String selected;
  final void Function(String code, String symbol) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Choose your currency',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (final c in _currencies)
          ListTile(
            leading: IconBadge(
              icon: LucideIcons.coins,
              color: Theme.of(context).colorScheme.primary,
              size: 38,
              iconSize: 17,
            ),
            title: Text('${c.$1}  (${c.$2.trim()})'),
            trailing: c.$1 == selected
                ? Icon(
                    LucideIcons.circleCheck,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => onSelect(c.$1, c.$2),
          ),
      ],
    );
  }
}

class _AccountsPage extends StatelessWidget {
  const _AccountsPage({
    required this.cash,
    required this.bank,
    required this.currency,
    required this.symbol,
  });

  final TextEditingController cash;
  final TextEditingController bank;
  final String currency;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Add your accounts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Set starting balances (optional).'),
        const SizedBox(height: 24),
        MoneyField(
          controller: cash,
          currency: currency,
          label: 'Cash',
          symbol: symbol,
        ),
        const SizedBox(height: 16),
        MoneyField(
          controller: bank,
          currency: currency,
          label: 'Bank',
          symbol: symbol,
        ),
      ],
    );
  }
}
