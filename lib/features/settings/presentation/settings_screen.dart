import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_select.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:ledgr/features/settings/presentation/pin_setup_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _currencies = <(String, String, String)>[
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

const _lockTimeouts = <(int, String)>[
  (0, 'Immediately'),
  (1, 'After 1 minute'),
  (5, 'After 5 minutes'),
  (15, 'After 15 minutes'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    Widget lead(IconData icon, {Color? color}) =>
        IconBadge(icon: icon, color: color ?? scheme.primary, iconSize: 18);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
        children: [
          GroupCard(
            title: 'Appearance',
            children: [
              ListTile(
                leading: lead(LucideIcons.palette),
                title: const Text('Theme'),
                trailing: LedgrSelect<ThemeMode>(
                  label: 'Theme',
                  compact: true,
                  value: settings.themeMode,
                  onChanged: controller.setThemeMode,
                  options: const [
                    LedgrSelectOption(
                      value: ThemeMode.system,
                      label: 'System',
                      icon: LucideIcons.monitorSmartphone,
                    ),
                    LedgrSelectOption(
                      value: ThemeMode.light,
                      label: 'Light',
                      icon: LucideIcons.sun,
                    ),
                    LedgrSelectOption(
                      value: ThemeMode.dark,
                      label: 'Dark',
                      icon: LucideIcons.moon,
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                secondary: lead(LucideIcons.sparkles),
                title: const Text('Dynamic color'),
                subtitle: const Text('Use the system wallpaper palette'),
                value: settings.dynamicColor,
                onChanged: (v) => controller.setDynamicColor(enabled: v),
              ),
              SwitchListTile(
                secondary: lead(LucideIcons.eyeOff),
                title: const Text('Hide amounts'),
                subtitle: const Text('Blur balances until you tap the eye'),
                value: settings.amountsHidden,
                onChanged: (_) => controller.toggleAmountsHidden(),
              ),
            ],
          ),
          GroupCard(
            title: 'Behavior',
            children: [
              ListTile(
                leading: lead(LucideIcons.calendarDays),
                title: const Text('Month starts on'),
                subtitle: const Text('For budgets and reports'),
                trailing: LedgrSelect<int>(
                  label: 'Month starts on',
                  compact: true,
                  value: settings.monthStartDay,
                  onChanged: controller.setMonthStartDay,
                  options: [
                    for (var day = 1; day <= 28; day++)
                      LedgrSelectOption(value: day, label: 'Day $day'),
                  ],
                ),
              ),
              ListTile(
                leading: lead(LucideIcons.coins),
                title: const Text('Currency'),
                subtitle: const Text("Labels only — amounts aren't converted"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${settings.homeCurrency} '
                      '(${settings.currencySymbol.trim()})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Gaps.sm),
                    const Icon(LucideIcons.chevronRight, size: 18),
                  ],
                ),
                onTap: () => _pickCurrency(context, ref),
              ),
            ],
          ),
          GroupCard(
            title: 'Security',
            children: [
              SwitchListTile(
                secondary: lead(LucideIcons.lock),
                title: const Text('App lock'),
                subtitle: const Text('Require a PIN to open'),
                value: settings.lockEnabled,
                onChanged: (v) async {
                  if (v) {
                    final set = await PinSetupSheet.show(context);
                    if (set ?? false) {
                      await controller.setLockEnabled(enabled: true);
                    }
                  } else {
                    await ref.read(appLockServiceProvider).clear();
                    await controller.setLockEnabled(enabled: false);
                    await controller.setBiometricEnabled(enabled: false);
                  }
                },
              ),
              if (settings.lockEnabled) ...[
                ListTile(
                  leading: lead(LucideIcons.rectangleEllipsis),
                  title: const Text('Change PIN'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => PinSetupSheet.show(context),
                ),
                ListTile(
                  leading: lead(LucideIcons.timer),
                  title: const Text('Auto-lock'),
                  trailing: LedgrSelect<int>(
                    label: 'Auto-lock',
                    compact: true,
                    value: settings.lockTimeoutMinutes,
                    onChanged: controller.setLockTimeout,
                    options: [
                      for (final (minutes, label) in _lockTimeouts)
                        LedgrSelectOption(value: minutes, label: label),
                    ],
                  ),
                ),
                SwitchListTile(
                  secondary: lead(LucideIcons.fingerprint),
                  title: const Text('Biometric unlock'),
                  value: settings.biometricEnabled,
                  onChanged: (v) => controller.setBiometricEnabled(enabled: v),
                ),
              ],
            ],
          ),
          GroupCard(
            title: 'Notifications',
            children: [
              SwitchListTile(
                secondary: lead(LucideIcons.bell),
                title: const Text('Budget alerts'),
                value: settings.notificationsEnabled,
                onChanged: (v) =>
                    controller.setNotificationsEnabled(enabled: v),
              ),
            ],
          ),
          GroupCard(
            title: 'Categories',
            children: [
              ListTile(
                leading: lead(LucideIcons.shapes),
                title: const Text('Manage categories'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => context.push('/categories'),
              ),
            ],
          ),
          GroupCard(
            title: 'Data',
            children: [
              ListTile(
                leading: lead(LucideIcons.upload),
                title: const Text('Export backup'),
                subtitle: const Text('Share a JSON file of everything'),
                onTap: () => _exportBackup(ref),
              ),
              ListTile(
                leading: lead(LucideIcons.download),
                title: const Text('Import backup'),
                subtitle: const Text('Restore from a backup — replaces '
                    'current data'),
                onTap: () => _importBackup(context, ref),
              ),
              ListTile(
                leading: lead(LucideIcons.trash2, color: scheme.expense),
                title: Text(
                  'Clear all data',
                  style: TextStyle(color: scheme.expense),
                ),
                onTap: () => _clearData(context, ref),
              ),
            ],
          ),
          GroupCard(
            title: 'About',
            children: [
              AboutListTile(
                icon: lead(LucideIcons.info),
                applicationName: 'Ledgr',
                applicationVersion: '1.0.0',
                aboutBoxChildren: const [
                  Text('Private, offline-first personal finance tracker.'),
                ],
              ),
              ListTile(
                leading: lead(LucideIcons.userRound),
                title: const Text('About the developer'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => _showDeveloper(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeveloper(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, Gaps.md, 28, Gaps.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(
                icon: LucideIcons.codeXml,
                color: scheme.primary,
                size: 56,
                iconSize: 26,
              ),
              const SizedBox(height: Gaps.lg),
              Text(
                'Syed Abdullah Saad',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Gaps.xs),
              Text(
                'Full-stack & AI engineer',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gaps.lg),
              Text(
                'Ledgr is built and maintained by one person who wanted a '
                'finance tracker that never phones home. Your data stays '
                'on this device — there is nothing to sign into and no '
                'server to trust.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gaps.md),
              Text(
                'github.com/AbdullahSaad5',
                style: text.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gaps.xs),
              Text(
                'syedabdullahsaad1@gmail.com',
                style: text.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final current = ref.read(appSettingsProvider).homeCurrency;
    final picked = await showModalBottomSheet<(String, String, String)>(
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
          child: _CurrencySheet(current: current),
        ),
      ),
    );
    if (picked != null) {
      await controller.setCurrency(picked.$1, picked.$2);
    }
  }

  Future<void> _exportBackup(WidgetRef ref) async {
    final json = await ref.read(backupServiceProvider).export();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ledgr_backup.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: 'Ledgr backup');
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open your ledgr_backup.json, copy its contents, and paste '
              'them below. Importing replaces everything currently in '
              'the app.',
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: text,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste backup JSON here',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) {
      text.dispose();
      return;
    }
    try {
      await ref.read(backupServiceProvider).import(text.text.trim());
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import backup: $e')),
      );
    } finally {
      text.dispose();
    }
  }

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every account, transaction, budget, and '
          'debt. Export a backup first if you want to keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      // Offer a backup first.
      await _exportBackup(ref);
      final db = ref.read(databaseProvider);
      await db.transaction(() async {
        await db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in db.allTables) {
          await db.delete(table).go();
        }
      });
      messenger.showSnackBar(const SnackBar(content: Text('Data cleared')));
    }
  }
}

/// Searchable currency list: filters by code, name, or symbol as you type.
class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.current});

  final String current;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
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
    final matches = _currencies
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
