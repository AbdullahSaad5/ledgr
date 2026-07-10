import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Create a debt in the given [direction].
class DebtFormSheet extends ConsumerStatefulWidget {
  const DebtFormSheet({required this.direction, super.key});

  final DebtDirection direction;

  static Future<void> show(BuildContext context, DebtDirection direction) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => DebtFormSheet(direction: direction),
      ),
    );
  }

  @override
  ConsumerState<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<DebtFormSheet> {
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _accountId;
  DateTime? _dueDate;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final person = _person.text.trim();
    final currency = ref.read(appSettingsProvider).homeCurrency;
    final principal = MoneyField.parse(_amount.text, currency).minor;
    if (person.isEmpty || principal <= 0) return;
    await ref
        .read(debtRepositoryProvider)
        .create(
          person: person,
          direction: widget.direction,
          principalMinor: principal,
          currency: currency,
          accountId: _accountId,
          dueDate: _dueDate,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final lent = widget.direction == DebtDirection.lent;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(lent ? 'I lent money' : 'I borrowed money'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
        children: [
          GroupCard(
            title: 'Who & how much',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.sm,
                ),
                child: TextField(
                  controller: _person,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Person',
                    prefixIcon: Icon(
                      LucideIcons.user,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.sm,
                  Gaps.lg,
                  Gaps.lg,
                ),
                child: MoneyField(
                  controller: _amount,
                  currency: settings.homeCurrency,
                  label: 'Amount',
                  symbol: settings.currencySymbol,
                ),
              ),
            ],
          ),
          GroupCard(
            title: 'Money movement',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.md,
                ),
                child: DropdownButtonFormField<int?>(
                  initialValue: _accountId,
                  decoration: InputDecoration(
                    labelText: lent ? 'From account' : 'Into account',
                    helperText: lent
                        ? 'Posts the loan as money leaving'
                        : 'Posts the borrowing as money arriving',
                  ),
                  items: [
                    const DropdownMenuItem(
                      child: Text('Don’t post a transaction'),
                    ),
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              ),
              ListTile(
                leading: IconBadge(
                  icon: LucideIcons.calendarClock,
                  color: scheme.primary,
                  size: 40,
                  iconSize: 18,
                ),
                title: const Text('Due date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'Optional'
                      : DateFormat('EEE, d MMM yyyy').format(_dueDate!),
                  style: TextStyle(
                    color: _dueDate == null
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                    fontWeight: _dueDate == null ? null : FontWeight.w600,
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
            ],
          ),
          GroupCard(
            title: 'Note',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    hintText: 'Anything worth remembering (optional)',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          Gaps.page,
          Gaps.sm,
          Gaps.page,
          Gaps.md,
        ),
        child: SizedBox(
          height: 52,
          child: FilledButton(onPressed: _save, child: const Text('Save')),
        ),
      ),
    );
  }
}
