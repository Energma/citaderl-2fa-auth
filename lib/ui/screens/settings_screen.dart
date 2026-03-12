import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/providers.dart';
import '../../core/crypto/import_export.dart';
import '../../ui/theme/palette.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(theme, 'Appearance'),
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Theme'),
            subtitle: Text(_themeModeLabel(themeMode)),
            onTap: () => _showThemePicker(context, ref),
          ),

          _sectionHeader(theme, 'Security'),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biometric Unlock'),
            subtitle: const Text('Use fingerprint or face to unlock'),
            trailing: FutureBuilder<bool>(
              future: ref.read(keystoreServiceProvider).isBiometricEnabled(),
              builder: (ctx, snap) {
                return Switch(
                  value: snap.data ?? false,
                  onChanged: (v) async {
                    final keystore = ref.read(keystoreServiceProvider);
                    if (v) {
                      final bio = ref.read(biometricServiceProvider);
                      final available = await bio.isAvailable();
                      if (!available) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Biometrics not available')),
                          );
                        }
                        return;
                      }
                    }
                    await keystore.setBiometricEnabled(v);
                    (ctx as Element).markNeedsBuild();
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Auto-lock Timeout'),
            subtitle: Text(_formatDuration(ref.watch(autoLockDurationProvider))),
            onTap: () => _showAutoLockPicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Lock Now'),
            onTap: () {
              ref.read(vaultProvider.notifier).lock();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),

          _sectionHeader(theme, 'Data'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import Tokens'),
            subtitle: const Text('From other authenticator apps'),
            onTap: () => _importTokens(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export Tokens'),
            subtitle: const Text('Encrypted or plaintext backup'),
            onTap: () => _showExportDialog(context, ref),
          ),

          _sectionHeader(theme, 'About'),
          ListTile(
            leading: SvgPicture.asset(
              'assets/logo/citadel_logo.svg',
              width: 24,
              height: 24,
            ),
            title: const Text('Citadel Auth'),
            subtitle: const Text('v0.1.0 - Privacy-first 2FA'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Open Source'),
            subtitle: Text('GPL-3.0 License'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy Commitment'),
            subtitle: Text(
              'No telemetry. No analytics. No cloud dependency. '
              'Export will NEVER be paywalled.',
            ),
          ),

          _sectionHeader(theme, 'Danger Zone'),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text('Delete Vault', style: TextStyle(color: theme.colorScheme.error)),
            subtitle: const Text('Permanently delete all data'),
            onTap: () => _deleteVault(context, ref),
          ),
          const SizedBox(height: 24),

          // Powered by Energma
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'Powered by',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                const SizedBox(height: 6),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          _themeOption(ctx, ref, ThemeMode.system, 'System default', Icons.brightness_auto, current),
          _themeOption(ctx, ref, ThemeMode.light, 'Light', Icons.light_mode, current),
          _themeOption(ctx, ref, ThemeMode.dark, 'Dark', Icons.dark_mode, current),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, WidgetRef ref, ThemeMode mode, String label, IconData icon, ThemeMode current) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeModeProvider.notifier).state = mode;
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (mode == current) const Icon(Icons.check, size: 20, color: Palette.primary),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes == 0) return 'Immediately';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    return '${d.inHours} hour${d.inHours > 1 ? 's' : ''}';
  }

  void _showAutoLockPicker(BuildContext context, WidgetRef ref) {
    final options = [
      (const Duration(minutes: 0), 'Immediately'),
      (const Duration(minutes: 1), '1 minute'),
      (const Duration(minutes: 5), '5 minutes'),
      (const Duration(minutes: 15), '15 minutes'),
      (const Duration(minutes: 30), '30 minutes'),
      (const Duration(hours: 1), '1 hour'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-lock Timeout'),
        children: options.map((o) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(autoLockDurationProvider.notifier).state = o.$1;
              Navigator.pop(ctx);
            },
            child: Text(o.$2),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _importTokens(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    try {
      final tokens = ImportExport.importFromJson(content);
      if (tokens.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tokens found in file')),
          );
        }
        return;
      }

      await ref.read(tokenRepositoryProvider).importTokens(tokens);
      ref.invalidate(tokenListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${tokens.length} tokens')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Tokens'),
        content: const Text('Choose export format. Plaintext exports contain your secret keys in readable form.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportTokens(context, ref, encrypted: false);
            },
            child: const Text('Plaintext (JSON)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportTokens(context, ref, encrypted: false);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTokens(BuildContext context, WidgetRef ref, {required bool encrypted}) async {
    final tokens = await ref.read(tokenRepositoryProvider).getAll();
    if (tokens.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tokens to export')),
        );
      }
      return;
    }

    final json = ImportExport.exportToJson(tokens);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/citadel_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Citadel Auth backup',
    );
  }

  void _deleteVault(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vault'),
        content: const Text(
          'This will permanently delete ALL your tokens and data. '
          'This action cannot be undone. Make sure you have exported a backup.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(vaultDatabaseProvider);
      await db.deleteVault();
      final keystore = ref.read(keystoreServiceProvider);
      await keystore.clearAll();
      ref.read(vaultProvider.notifier).checkStatus();
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }
}
