import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/widgets/ledgr_field.dart';
import 'package:ledgr/core/widgets/sheet_insets.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';

/// Set a 4–6 digit PIN (entered twice to confirm). Returns true when saved.
class PinSetupSheet extends ConsumerStatefulWidget {
  const PinSetupSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PinSetupSheet(),
    );
  }

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _first.text.trim();
    final b = _second.text.trim();
    if (a.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    if (a != b) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    await ref.read(appLockServiceProvider).setPin(a);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        sheetBottomInset(context, min: 24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set a PIN', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          LedgrField(
            controller: _first,
            label: 'PIN',
            hint: '••••',
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          LedgrField(
            controller: _second,
            label: 'Confirm PIN',
            hint: '••••',
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _error,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save PIN')),
        ],
      ),
    );
  }
}
