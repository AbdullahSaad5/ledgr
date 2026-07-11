import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/providers/database_provider.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/currency_picker_sheet.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_select.dart';
import 'package:ledgr/features/backup/data/auto_backup_service.dart';
import 'package:ledgr/features/backup/data/csv_importer.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:ledgr/features/settings/presentation/pin_setup_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
        padding: EdgeInsets.fromLTRB(
          Gaps.page,
          0,
          Gaps.page,
          MediaQuery.paddingOf(context).bottom + Gaps.xxl,
        ),
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
              SwitchListTile(
                secondary: lead(LucideIcons.calendarSync),
                title: const Text('Daily auto-backup'),
                subtitle: const Text('Keeps the last 7 snapshots on this '
                    'device — nothing leaves it'),
                value: settings.autoBackupEnabled,
                onChanged: (v) => _setAutoBackup(context, ref, enabled: v),
              ),
              ListTile(
                leading: lead(LucideIcons.fileClock),
                title: const Text('Share latest auto-backup'),
                onTap: () => _shareLatestAutoBackup(context, ref),
              ),
              ListTile(
                leading: lead(LucideIcons.fileSpreadsheet),
                title: const Text('Import CSV'),
                subtitle: const Text('Add transactions from a Ledgr CSV '
                    'export — duplicates are skipped'),
                onTap: () => _importCsv(context, ref),
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
    final picked = await CurrencyPickerSheet.show(context, current: current);
    if (picked != null) {
      await controller.setCurrency(picked.$1, picked.$2);
    }
  }

  /// Exports and opens the share sheet; reports whether the user actually
  /// shared the file (dismissing the sheet counts as not shared).
  Future<bool> _exportBackup(WidgetRef ref) async {
    final json = await ref.read(backupServiceProvider).export();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ledgr_backup.json');
    await file.writeAsString(json);
    final result = await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Ledgr backup',
    );
    return result.status != ShareResultStatus.dismissed;
  }

  Future<void> _setAutoBackup(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(settingsControllerProvider.notifier)
        .setAutoBackupEnabled(enabled: enabled);
    if (enabled) {
      await const AutoBackupService().enable();
      // Snapshot right away so the toggle visibly did something.
      final docs = await getApplicationDocumentsDirectory();
      await AutoBackupService.snapshot(ref.read(databaseProvider), docs);
      messenger.showSnackBar(
        const SnackBar(content: Text('Auto-backup on — first snapshot saved')),
      );
    } else {
      await const AutoBackupService().disable();
    }
  }

  Future<void> _shareLatestAutoBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final docs = await getApplicationDocumentsDirectory();
    final latest = await AutoBackupService.latest(docs);
    if (latest == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No auto-backup yet — turn it on first')),
      );
      return;
    }
    await Share.shareXFiles([XFile(latest.path)], subject: 'Ledgr backup');
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final currency = ref.read(appSettingsProvider).homeCurrency;
    final db = ref.read(databaseProvider);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    try {
      final csv = await File(path).readAsString();
      final summary = await CsvImporter(db).import(csv, currency: currency);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${summary.imported} transaction'
            '${summary.imported == 1 ? '' : 's'}'
            '${summary.skipped > 0 ? ', skipped ${summary.skipped}' : ''}',
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import that file: $e')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // File first (the natural path since exports are files); paste stays as
    // the fallback for JSON coming from anywhere else.
    final source = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.fileJson, size: 20),
              title: const Text('Pick a backup file'),
              onTap: () => Navigator.of(sheetContext).pop('file'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.clipboardPaste, size: 20),
              title: const Text('Paste JSON'),
              onTap: () => Navigator.of(sheetContext).pop('paste'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == 'file') {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore backup?'),
          content: const Text(
            'Importing replaces everything currently in the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return;
      try {
        await ref
            .read(backupServiceProvider)
            .import(await File(path).readAsString());
        // Receipt images of the replaced data would otherwise leak on disk.
        await ref.read(attachmentRepositoryProvider).pruneOrphanFiles();
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup restored')),
        );
        // on Object: malformed-but-valid JSON surfaces as TypeError/RangeError
        // (Error, not Exception); the transaction has already rolled back.
      } on Object catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not import backup: $e')),
        );
      }
      return;
    }

    if (!context.mounted) return;
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
      // Receipt images of the replaced data would otherwise leak on disk.
      await ref.read(attachmentRepositoryProvider).pruneOrphanFiles();
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
      // on Object: see the file-import path above.
    } on Object catch (e) {
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
      // Offer a backup first. Dismissing the share sheet reads as a change of
      // heart, so it aborts the wipe instead of proceeding silently.
      var backedUp = false;
      try {
        backedUp = await _exportBackup(ref);
      } on Object catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Backup failed, nothing cleared: $e')),
        );
        return;
      }
      if (!backedUp) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Clear cancelled — no backup taken')),
        );
        return;
      }
      // Clears back to fresh-install state: defaults re-seeded, not empty.
      await ref.read(backupServiceProvider).clearAll();
      // The wipe dropped the attachment rows; drop their files too.
      await ref.read(attachmentRepositoryProvider).pruneOrphanFiles();
      messenger.showSnackBar(const SnackBar(content: Text('Data cleared')));
    }
  }
}
