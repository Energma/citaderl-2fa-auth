import '../../core/models/token.dart';
import '../database/vault_database.dart';

class TokenRepository {
  final VaultDatabase _db;

  TokenRepository(this._db);

  Future<List<Token>> getAll() => _db.getAllTokens();

  Future<List<Token>> getByProfile(String profileId) => _db.getTokensByProfile(profileId);

  Future<void> add(Token token) => _db.insertToken(token);

  Future<void> update(Token token) => _db.updateToken(token);

  Future<void> delete(String id) => _db.deleteToken(id);

  Future<void> incrementHotpCounter(Token token) async {
    await _db.updateHotpCounter(token.id, token.counter + 1);
  }

  Future<List<Token>> search(String query) => _db.searchTokens(query);

  Future<void> importTokens(List<Token> tokens) => _db.insertTokens(tokens);

  Future<int> count() => _db.tokenCount();

  Future<void> updateSortOrders(Map<String, int> idToOrder) =>
      _db.updateTokenSortOrders(idToOrder);

  Future<void> updateProfile(String tokenId, String? profileId) =>
      _db.updateTokenProfile(tokenId, profileId);

  Future<void> updateGroup(String tokenId, String? groupId) =>
      _db.updateTokenGroup(tokenId, groupId);
}
