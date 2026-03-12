import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-secure key storage using Android Keystore / iOS Keychain.
class KeystoreService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _vaultKeyKey = 'citadel_vault_key';
  static const _saltKey = 'citadel_vault_salt';
  static const _biometricEnabledKey = 'citadel_biometric_enabled';

  /// Store the derived vault key in secure storage.
  Future<void> storeVaultKey(Uint8List key) async {
    await _storage.write(key: _vaultKeyKey, value: base64.encode(key));
  }

  /// Retrieve the stored vault key.
  Future<Uint8List?> getVaultKey() async {
    final encoded = await _storage.read(key: _vaultKeyKey);
    if (encoded == null) return null;
    return Uint8List.fromList(base64.decode(encoded));
  }

  /// Remove the stored vault key (lock).
  Future<void> clearVaultKey() async {
    await _storage.delete(key: _vaultKeyKey);
  }

  /// Store the salt used for key derivation.
  Future<void> storeSalt(Uint8List salt) async {
    await _storage.write(key: _saltKey, value: base64.encode(salt));
  }

  /// Retrieve the stored salt.
  Future<Uint8List?> getSalt() async {
    final encoded = await _storage.read(key: _saltKey);
    if (encoded == null) return null;
    return Uint8List.fromList(base64.decode(encoded));
  }

  /// Check if biometric unlock is enabled.
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Enable or disable biometric unlock.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  /// Clear all stored keys (full reset).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
