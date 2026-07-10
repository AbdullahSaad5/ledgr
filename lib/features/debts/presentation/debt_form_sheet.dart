import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/group_card.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_field.dart';
import 'package:ledgr/core/widgets/ledgr_select.dart';
import 'package:ledgr/core/widgets/money_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Create a debt in the given [direction], or edit an existing one's
/// person / due date / note (money movement is locked after creation).
class DebtFormSheet extends ConsumerStatefulWidget {
  const DebtFormSheet({required this.direction, this.debt, super.key});

  final DebtDirection direction;
  final Debt? debt;

  static Future<void> show(
    BuildContext context,
    DebtDirection direction, {
    Debt? debt,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => DebtFormSheet(direction: direction, debt: debt),
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

  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _person.text = d.person;
      _dueDate = d.dueDate;
      _note.text = d.note ?? '';
    }
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final person = _person.text.trim();
    if (person.isEmpty) return;
    final repo = ref.read(debtRepositoryProvider);
    if (_isEditing) {
      await repo.update(
        widget.debt!.id,
        person: person,
        dueDate: _dueDate,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    } else {
      final currency = ref.read(appSettingsProvider).homeCurrency;
      final principal = MoneyField.parse(_amount.text, currency).minor;
      if (principal <= 0) return;
      await repo.create(
        person: person,
        direction: widget.direction,
        principalMinor: principal,
        currency: currency,
        accountId: _accountId,
        dueDate: _dueDate,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    }
    await ref.read(debtReminderServiceProvider).syncAll();
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
        title: Text(
          _isEditing
              ? 'Edit debt'
              : (lent ? 'I lent money' : 'I borrowed money'),
        ),
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
                child: LedgrField(
                  controller: _person,
                  label: 'Person',
                  hint: 'Who is this with?',
                  prefixIcon: LucideIcons.user,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              if (!_isEditing)
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
                )
              else
                const SizedBox(height: Gaps.sm),
            ],
          ),
          GroupCard(
            title: 'Money movement',
            children: [
              if (_isEditing)
                const Padding(
                  padding: EdgeInsets.all(Gaps.lg),
                  child: Text(
                    'Amount and account are locked once a debt exists — '
                    'record payments instead.',
                  ),
                )
              else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.lg,
                  Gaps.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LedgrSelect<int?>(
                      label: lent ? 'From account' : 'Into account',
                      value: _accountId,
                      options: [
                        const LedgrSelectOption(
                          value: null,
                          label: 'Don’t post a transaction',
                          icon: LucideIcons.circleOff,
                        ),
                        for (final a in accounts)
                          LedgrSelectOption(
                            value: a.id,
                            label: a.name,
                            icon: AppIcons.resolve(a.icon),
                            iconColor: Color(a.color),
                          ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lent
                          ? 'Posts the loan as money leaving'
                          : 'Posts the borrowing as money arriving',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
