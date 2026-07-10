import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/currency_picker_sheet.dart';
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
  final _wallet = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    _cash.dispose();
    _bank.dispose();
    _wallet.dispose();
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
    if (_wallet.text.trim().isNotEmpty) {
      await accounts.create(
        name: 'Mobile Wallet',
        type: AccountType.wallet,
        icon: 'wallet',
        color: 0xFF8E24AA,
        currency: currency,
        openingBalanceMinor: MoneyField.parse(_wallet.text, currency).minor,
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Quiet top edge: just an escape hatch.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.page,
                  Gaps.xs,
                  Gaps.md,
                  0,
                ),
                child: TextButton(onPressed: _skip, child: const Text('Skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _WelcomePage(),
                  _CurrencyPage(
                    selected: settings.homeCurrency,
                    onSelect: (code, symbol) => ref
                        .read(settingsControllerProvider.notifier)
                        .setCurrency(code, symbol),
                  ),
                  _AccountsPage(
                    cash: _cash,
                    bank: _bank,
                    wallet: _wallet,
                    currency: settings.homeCurrency,
                    symbol: settings.currencySymbol,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.page,
                Gaps.md,
                Gaps.page,
                Gaps.xl,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 7),
                      width: i == _page ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: i == _page
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                      ),
                      onPressed: _page == 2
                          ? _finish
                          : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            ),
                      child: Text(_page == 2 ? 'Get started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 1 — the brand moment: mark, name, and the three promises.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[
      const Center(child: LedgrLogoMark(size: 108)),
      const SizedBox(height: Gaps.xl),
      Text(
        'Welcome to Ledgr',
        textAlign: TextAlign.center,
        style: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: Gaps.sm),
      Text(
        'Your money, on your phone. Nowhere else.',
        textAlign: TextAlign.center,
        style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: Gaps.xxl),
      const _Promise(
        icon: LucideIcons.zap,
        title: 'Capture in seconds',
        caption: 'A calculator keypad, not a form.',
      ),
      const _Promise(
        icon: LucideIcons.shieldCheck,
        title: 'Private by design',
        caption: 'No account, no cloud, no network permission.',
      ),
      const _Promise(
        icon: LucideIcons.chartPie,
        title: 'See where it goes',
        caption: 'Budgets, reports, and debt tracking built in.',
      ),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .animate(interval: 60.ms)
              .fadeIn(duration: 350.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, duration: 350.ms),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
      child: Row(
        children: [
          IconBadge(icon: icon, color: scheme.primary, size: 42, iconSize: 19),
          const SizedBox(width: Gaps.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  caption,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 2 — home currency. One card, one obvious selection.
class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage({required this.selected, required this.onSelect});

  final String selected;
  final void Function(String code, String symbol) onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Gaps.page,
        Gaps.md,
        Gaps.page,
        Gaps.xl,
      ),
      children: [
        Text(
          'Choose your currency',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: Gaps.xs),
        Text(
          'Every amount in Ledgr uses one home currency. You can change it '
          'later in Settings.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Gaps.xl),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, c) in _currencies.indexed) ...[
                if (i > 0)
                  Divider(height: 1, indent: 68, color: scheme.outlineVariant),
                _CurrencyTile(
                  code: c.$1,
                  symbol: c.$2,
                  selected: c.$1 == selected,
                  onTap: () => onSelect(c.$1, c.$2),
                ),
              ],
              Divider(height: 1, indent: 68, color: scheme.outlineVariant),
              // The full searchable catalog for everyone else (#17 gap fix:
              // onboarding used to offer only these six).
              ListTile(
                leading: const SizedBox(
                  width: 44,
                  child: Icon(LucideIcons.globe, size: 20),
                ),
                title: Text(
                  _currencies.any((c) => c.$1 == selected)
                      ? 'More currencies…'
                      : '$selected (selected)',
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final picked = await CurrencyPickerSheet.show(
                    context,
                    current: selected,
                  );
                  if (picked != null) onSelect(picked.$1, picked.$2);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.code,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gaps.lg,
          vertical: Gaps.md,
        ),
        child: Row(
          children: [
            if (selected)
              IconBadge.filled(
                icon: LucideIcons.coins,
                fill: scheme.primary,
                onColor: scheme.onPrimary,
                size: 40,
                iconSize: 18,
              )
            else
              IconBadge(
                icon: LucideIcons.coins,
                color: scheme.onSurfaceVariant,
                size: 40,
                iconSize: 18,
              ),
            const SizedBox(width: Gaps.lg),
            Expanded(
              child: Text(
                '$code  (${symbol.trim()})',
                style: text.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selected ? 1 : 0,
              child: Icon(LucideIcons.circleCheck, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 3 — starting balances, both optional.
class _AccountsPage extends StatelessWidget {
  const _AccountsPage({
    required this.cash,
    required this.bank,
    required this.wallet,
    required this.currency,
    required this.symbol,
  });

  final TextEditingController cash;
  final TextEditingController bank;
  final TextEditingController wallet;
  final String currency;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Gaps.page,
        Gaps.md,
        Gaps.page,
        Gaps.xl,
      ),
      children: [
        Text(
          'Add your accounts',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: Gaps.xs),
        Text(
          'Set what each one holds right now — or skip this and add accounts '
          'anytime.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Gaps.xl),
        _AccountField(
          icon: LucideIcons.banknote,
          accent: const Color(0xFF43A047),
          controller: cash,
          currency: currency,
          label: 'Cash',
          symbol: symbol,
        ),
        const SizedBox(height: Gaps.md),
        _AccountField(
          icon: LucideIcons.landmark,
          accent: const Color(0xFF1565C0),
          controller: bank,
          currency: currency,
          label: 'Bank',
          symbol: symbol,
        ),
        const SizedBox(height: Gaps.md),
        _AccountField(
          icon: LucideIcons.smartphone,
          accent: const Color(0xFF8E24AA),
          controller: wallet,
          currency: currency,
          label: 'Mobile Wallet',
          symbol: symbol,
        ),
      ],
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.icon,
    required this.accent,
    required this.controller,
    required this.currency,
    required this.label,
    required this.symbol,
  });

  final IconData icon;
  final Color accent;
  final TextEditingController controller;
  final String currency;
  final String label;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.lg),
        child: Row(
          children: [
            IconBadge(icon: icon, color: accent, size: 44, iconSize: 20),
            const SizedBox(width: Gaps.lg),
            Expanded(
              child: MoneyField(
                controller: controller,
                currency: currency,
                label: label,
                symbol: symbol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
