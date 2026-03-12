import '../../core/models/profile.dart';
import '../database/vault_database.dart';

class ProfileRepository {
  final VaultDatabase _db;

  ProfileRepository(this._db);

  Future<List<Profile>> getAll() => _db.getAllProfiles();

  Future<void> add(Profile profile) => _db.insertProfile(profile);

  Future<void> update(Profile profile) => _db.updateProfile(profile);

  Future<void> delete(String id) => _db.deleteProfile(id);

  Future<List<TokenGroup>> getGroups(String profileId) => _db.getGroupsByProfile(profileId);

  Future<void> addGroup(TokenGroup group) => _db.insertGroup(group);

  Future<void> deleteGroup(String id) => _db.deleteGroup(id);
}
