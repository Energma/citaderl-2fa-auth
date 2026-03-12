import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/otp_engine.dart';
import '../../core/models/token.dart';
import '../../core/providers.dart';
import '../widgets/qr_scanner.dart';

class AddTokenScreen extends ConsumerStatefulWidget {
  final Token? editToken;

  const AddTokenScreen({super.key, this.editToken});

  @override
  ConsumerState<AddTokenScreen> createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends ConsumerState<AddTokenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _issuerController = TextEditingController();
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();
  final _uriController = TextEditingController();

  OtpType _type = OtpType.totp;
  Algorithm _algorithm = Algorithm.sha1;
  int _digits = 6;
  int _period = 30;
  String? _profileId;
  String? _error;

  bool get _isEditing => widget.editToken != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isEditing ? 1 : 3, vsync: this);
    if (_isEditing) {
      final t = widget.editToken!;
      _issuerController.text = t.issuer;
      _accountController.text = t.account;
      _secretController.text = t.secret;
      _type = t.type;
      _algorithm = t.algorithm;
      _digits = t.digits;
      _period = t.period;
      _profileId = t.profileId;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _issuerController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    _uriController.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    final issuer = _issuerController.text.trim();
    final account = _accountController.text.trim();
    final secret = _secretController.text.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

    if (account.isEmpty) {
      setState(() => _error = 'Account name is required');
      return;
    }
    if (secret.isEmpty) {
      setState(() => _error = 'Secret key is required');
      return;
    }
    if (!OtpEngine.isValidSecret(secret)) {
      setState(() => _error = 'Invalid Base32 secret key');
      return;
    }

    final repo = ref.read(tokenRepositoryProvider);

    if (_isEditing) {
      final updated = widget.editToken!.copyWith(
        issuer: issuer,
        account: account,
        secret: secret,
        type: _type,
        algorithm: _algorithm,
        digits: _digits,
        period: _period,
        profileId: _profileId,
      );
      await repo.update(updated);
    } else {
      final token = Token(
        issuer: issuer,
        account: account,
        secret: secret,
        type: _type,
        algorithm: _algorithm,
        digits: _digits,
        period: _period,
        profileId: _profileId,
      );
      await repo.add(token);
    }

    if (mounted) Navigator.pop(context);
  }

  void _handleQrScanned(String code) {
    try {
      if (code.startsWith('otpauth://')) {
        final token = Token.fromUri(code);
        _issuerController.text = token.issuer;
        _accountController.text = token.account;
        _secretController.text = token.secret;
        setState(() {
          _type = token.type;
          _algorithm = token.algorithm;
          _digits = token.digits;
          _period = token.period;
          _error = null;
        });
        _tabController.animateTo(_tabController.length - 1); // Go to manual tab
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code scanned successfully')),
        );
      } else {
        setState(() => _error = 'Not a valid otpauth:// QR code');
      }
    } catch (e) {
      setState(() => _error = 'Failed to parse QR code: $e');
    }
  }

  void _handleUriPaste() {
    final uri = _uriController.text.trim();
    if (uri.isEmpty) return;
    _handleQrScanned(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Token' : 'Add Token'),
        bottom: _isEditing
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
                  Tab(icon: Icon(Icons.link), text: 'Paste URI'),
                  Tab(icon: Icon(Icons.edit), text: 'Manual'),
                ],
              ),
      ),
      body: _isEditing
          ? _buildManualForm(theme)
          : TabBarView(
              controller: _tabController,
              children: [
                // QR Scanner tab
                QrScannerWidget(onScanned: _handleQrScanned),
                // URI paste tab
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paste otpauth:// URI', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _uriController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'otpauth://totp/Example:user@email.com?secret=...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleUriPaste,
                          child: const Text('Parse URI'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ],
                  ),
                ),
                // Manual entry tab
                _buildManualForm(theme),
              ],
            ),
    );
  }

  Widget _buildManualForm(ThemeData theme) {
    final profiles = ref.watch(profileListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _issuerController,
            decoration: const InputDecoration(
              labelText: 'Service / Issuer',
              hintText: 'e.g. GitHub, Google, AWS',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountController,
            decoration: const InputDecoration(
              labelText: 'Account *',
              hintText: 'e.g. user@email.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretController,
            decoration: const InputDecoration(
              labelText: 'Secret Key (Base32) *',
              hintText: 'e.g. JBSWY3DPEHPK3PXP',
            ),
          ),
          const SizedBox(height: 16),

          // Profile selector
          profiles.when(
            data: (profileList) => DropdownButtonFormField<String?>(
              initialValue: _profileId,
              decoration: const InputDecoration(labelText: 'Profile'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...profileList.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: p.color, radius: 6),
                          const SizedBox(width: 8),
                          Text(p.name),
                        ],
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _profileId = v),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),
          // Advanced settings
          ExpansionTile(
            title: const Text('Advanced'),
            tilePadding: EdgeInsets.zero,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<OtpType>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: OtpType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<Algorithm>(
                      initialValue: _algorithm,
                      decoration: const InputDecoration(labelText: 'Algorithm'),
                      items: Algorithm.values
                          .map((a) => DropdownMenuItem(value: a, child: Text(a.name.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _algorithm = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _digits,
                      decoration: const InputDecoration(labelText: 'Digits'),
                      items: [6, 7, 8]
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (v) => setState(() => _digits = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _period,
                      decoration: const InputDecoration(labelText: 'Period (s)'),
                      items: [30, 60, 90]
                          .map((p) => DropdownMenuItem(value: p, child: Text('${p}s')))
                          .toList(),
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveToken,
              child: Text(_isEditing ? 'Save Changes' : 'Add Token'),
            ),
          ),
        ],
      ),
    );
  }
}
