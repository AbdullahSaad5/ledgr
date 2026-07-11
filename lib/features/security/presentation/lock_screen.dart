import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/features/security/presentation/lock_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// PIN + biometric unlock screen shown over the app while locked.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;
  int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    // Render exactly as many dots as the saved PIN has digits.
    ref.read(appLockServiceProvider).pinLength().then((length) {
      if (mounted) setState(() => _pinLength = length);
    });
    if (ref.read(appSettingsProvider).biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  Future<void> _biometric() async {
    final ok = await ref.read(appLockServiceProvider).authenticateBiometric();
    if (ok && mounted) ref.read(lockControllerProvider.notifier).unlock();
  }

  Future<void> _press(String digit) async {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = false;
    });
    if (_pin.length == _pinLength) {
      final ok = await ref.read(appLockServiceProvider).verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        ref.read(lockControllerProvider.notifier).unlock();
      } else {
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
      // Scrolls when logo + keypad exceed a short screen (big fonts,
      // 3-button nav) instead of clipping top and bottom.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LedgrLogoMark(size: 64),
                const SizedBox(height: 16),
                Text(
                  _error ? 'Wrong PIN, try again' : 'Enter your PIN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _error ? scheme.expense : null,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pinLength; i++)
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
              key(
                '',
                onTap: onBiometric,
                child: const Icon(LucideIcons.fingerprint),
              )
            else
              const SizedBox(width: 88),
            key('0'),
            key('', onTap: onBackspace, child: const Icon(LucideIcons.delete)),
          ],
        ),
      ],
    );
  }
}
