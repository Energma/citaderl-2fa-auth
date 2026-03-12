import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/vault_database.dart';
import '../data/repositories/token_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../platform/biometric_service.dart';
import '../platform/keystore_service.dart';
import 'models/token.dart';
import 'models/profile.dart';

// --- Singletons ---

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) => VaultDatabase());
final keystoreServiceProvider = Provider<KeystoreService>((ref) => KeystoreService());
final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  return TokenRepository(ref.watch(vaultDatabaseProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(vaultDatabaseProvider));
});

// --- Vault State ---

enum VaultStatus { uninitialized, locked, unlocked }

class VaultState {
  final VaultStatus status;
  VaultState(this.status);
}

class VaultNotifier extends StateNotifier<VaultState> {
  final VaultDatabase _db;

  VaultNotifier(this._db) : super(VaultState(VaultStatus.uninitialized));

  Future<void> checkStatus() async {
    final exists = await _db.exists();
    state = VaultState(exists ? VaultStatus.locked : VaultStatus.uninitialized);
  }

  Future<bool> createVault(String passphrase) async {
    try {
      await _db.open(passphrase);
      state = VaultState(VaultStatus.unlocked);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock(String passphrase) async {
    try {
      await _db.open(passphrase);
      state = VaultState(VaultStatus.unlocked);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> lock() async {
    await _db.close();
    state = VaultState(VaultStatus.locked);
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(ref.watch(vaultDatabaseProvider));
});

// --- Active Profile ---

final activeProfileIdProvider = StateProvider<String?>((ref) => null);

// --- Token List ---

final tokenListProvider = FutureProvider<List<Token>>((ref) async {
  final vault = ref.watch(vaultProvider);
  if (vault.status != VaultStatus.unlocked) return [];

  final repo = ref.read(tokenRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  if (profileId != null) {
    return repo.getByProfile(profileId);
  }
  return repo.getAll();
});

// --- Profile List ---

final profileListProvider = FutureProvider<List<Profile>>((ref) async {
  final vault = ref.watch(vaultProvider);
  if (vault.status != VaultStatus.unlocked) return [];
  return ref.read(profileRepositoryProvider).getAll();
});

// --- Search ---

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Token>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(tokenRepositoryProvider).search(query);
});

// --- Settings ---

final autoLockDurationProvider = StateProvider<Duration>((ref) => const Duration(minutes: 5));

// --- Theme ---

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
