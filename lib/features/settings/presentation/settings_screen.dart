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
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:ledgr/features/settings/presentation/pin_setup_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _currencies = <(String, String)>[
  ('PKR', 'Rs '),
  ('USD', r'$'),
  ('EUR', '€'),
  ('GBP', '£'),
  ('INR', '₹'),
  ('AED', 'AED '),
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
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  underline: const SizedBox.shrink(),
                  onChanged: (m) => controller.setThemeMode(m!),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
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
                trailing: DropdownButton<int>(
                  value: settings.monthStartDay,
                  underline: const SizedBox.shrink(),
                  menuMaxHeight: 360,
                  onChanged: (d) => controller.setMonthStartDay(d!),
                  items: [
                    for (var day = 1; day <= 28; day++)
                      DropdownMenuItem(value: day, child: Text('$day')),
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
                  trailing: DropdownButton<int>(
                    value: settings.lockTimeoutMinutes,
                    underline: const SizedBox.shrink(),
                    onChanged: (m) => controller.setLockTimeout(m!),
                    items: [
                      for (final (minutes, label) in _lockTimeouts)
                        DropdownMenuItem(value: minutes, child: Text(label)),
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
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final current = ref.read(appSettingsProvider).homeCurrency;
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
          children: [
            for (final c in _currencies)
              ListTile(
                leading: IconBadge(
                  icon: LucideIcons.coins,
                  color: Theme.of(sheetContext).colorScheme.primary,
                  size: 38,
                  iconSize: 17,
                ),
                title: Text('${c.$1}  (${c.$2.trim()})'),
                trailing: c.$1 == current
                    ? Icon(
                        LucideIcons.circleCheck,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
          ],
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
