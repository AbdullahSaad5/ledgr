import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';

/// PIN + biometric unlock screen shown over the app while locked.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(appSettingsProvider).biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  Future<void> _biometric() async {
    final ok = await ref.read(appLockServiceProvider).authenticateBiometric();
    if (ok && mounted) ref.read(lockControllerProvider.notifier).unlock();
  }

  Future<void> _press(String digit) async {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = false;
    });
    if (_pin.length >= 4) {
      final ok = await ref.read(appLockServiceProvider).verifyPin(_pin);
      if (ok) {
        ref.read(lockControllerProvider.notifier).unlock();
      } else if (_pin.length == 6) {
        setState(() {
          _error = true;
          _pin = '';
        });
      }
    }
  }

  void _backspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              _error ? 'Wrong PIN, try again' : 'Enter your PIN',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _error ? scheme.error : null,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            _Keypad(
              onDigit: _press,
              onBackspace: _backspace,
              onBiometric: ref.watch(appSettingsProvider).biometricEnabled
                  ? _biometric
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: OutlinedButton(
            onPressed: onTap ?? () => onDigit(label),
            style: OutlinedButton.styleFrom(shape: const CircleBorder()),
            child:
                child ??
                Text(label, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onBiometric != null)
              key('', onTap: onBiometric, child: const Icon(Icons.fingerprint))
            else
              const SizedBox(width: 88),
            key('0'),
            key(
              '',
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
