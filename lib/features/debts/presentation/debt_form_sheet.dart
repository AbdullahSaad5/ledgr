import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/money_field.dart';

/// Create a debt in the given [direction].
class DebtFormSheet extends ConsumerStatefulWidget {
  const DebtFormSheet({required this.direction, super.key});

  final DebtDirection direction;

  static Future<void> show(BuildContext context, DebtDirection direction) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DebtFormSheet(direction: direction),
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
    final lent = widget.direction == DebtDirection.lent;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lent ? 'I lent money' : 'I borrowed money',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _person,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Person',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            MoneyField(
              controller: _amount,
              currency: settings.homeCurrency,
              label: 'Amount',
              symbol: settings.currencySymbol,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: lent
                    ? 'From account (optional)'
                    : 'Into account (optional)',
                border: const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(child: Text('Don’t post a transaction')),
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _dueDate == null
                          ? 'Due date (optional)'
                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
