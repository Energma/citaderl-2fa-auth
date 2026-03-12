import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/providers.dart';
import '../../ui/theme/palette.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final biometric = ref.read(biometricServiceProvider);
    final keystore = ref.read(keystoreServiceProvider);

    final enabled = await keystore.isBiometricEnabled();
    if (!enabled) return;

    final available = await biometric.isAvailable();
    if (!available) return;

    final success = await biometric.authenticate();
    if (success && mounted) {
      final key = await keystore.getVaultKey();
      if (key != null) {
        // The stored key is the passphrase encoded as UTF-8
        final passphrase = String.fromCharCodes(key);
        await _unlock(passphrase);
      }
    }
  }

  Future<void> _unlock(String passphrase) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref.read(vaultProvider.notifier).unlock(passphrase);

    if (mounted) {
      setState(() => _loading = false);
      if (!success) {
        setState(() => _error = 'Wrong password. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/logo/citadel_logo.svg', width: 72, height: 72),
                      const SizedBox(height: 16),
                      Text(
                        'Citadel Auth',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your master password to unlock',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autofocus: true,
                        onSubmitted: (_) => _unlock(_passwordController.text),
                        decoration: InputDecoration(
                          hintText: 'Master password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _unlock(_passwordController.text),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Unlock'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Powered by Energma
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Powered by',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Palette.primary, Palette.accent],
                        ).createShader(bounds),
                        child: const Icon(Icons.bolt, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ENERGMA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ],
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
