import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/token.dart';
import '../../core/models/profile.dart';

class VaultDatabase {
  static const String _dbName = 'citadel_vault.db';
  static const int _dbVersion = 1;

  Database? _database;

  bool get isOpen => _database != null;

  Future<String> get _dbPath async {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, _dbName);
  }

  /// Open the encrypted database with the given passphrase.
  Future<void> open(String passphrase) async {
    if (_database != null) return;

    final path = await _dbPath;
    _database = await openDatabase(
      path,
      password: passphrase,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Close the database (lock the vault).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Check if the vault database exists.
  Future<bool> exists() async {
    final path = await _dbPath;
    return databaseExists(path);
  }

  /// Delete the vault (destructive).
  Future<void> deleteVault() async {
    await close();
    final path = await _dbPath;
    await deleteDatabase(path);
  }

  Database get _db {
    if (_database == null) throw StateError('Vault is locked');
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        iconName TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (profileId) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tokens (
        id TEXT PRIMARY KEY,
        issuer TEXT NOT NULL,
        account TEXT NOT NULL,
        secret TEXT NOT NULL,
        type TEXT NOT NULL,
        algorithm TEXT NOT NULL,
        digits INTEGER NOT NULL DEFAULT 6,
        period INTEGER NOT NULL DEFAULT 30,
        counter INTEGER NOT NULL DEFAULT 0,
        iconPath TEXT,
        profileId TEXT,
        groupId TEXT,
        tags TEXT,
        isPinned INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (profileId) REFERENCES profiles(id) ON DELETE SET NULL,
        FOREIGN KEY (groupId) REFERENCES groups(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tokens_profile ON tokens(profileId)');
    await db.execute('CREATE INDEX idx_tokens_group ON tokens(groupId)');

    // Insert default profiles
    await db.insert('profiles', Profile(
      name: 'Personal',
      colorValue: 0xFF6366F1, // indigo
      sortOrder: 0,
    ).toMap());
    await db.insert('profiles', Profile(
      name: 'Work',
      colorValue: 0xFF06B6D4, // cyan
      sortOrder: 1,
    ).toMap());
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  // --- Token CRUD ---

  Future<List<Token>> getAllTokens() async {
    final maps = await _db.query('tokens', orderBy: 'sortOrder ASC, createdAt DESC');
    return maps.map((m) => Token.fromMap(m)).toList();
  }

  Future<List<Token>> getTokensByProfile(String profileId) async {
    final maps = await _db.query(
      'tokens',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'isPinned DESC, sortOrder ASC',
    );
    return maps.map((m) => Token.fromMap(m)).toList();
  }

  Future<void> insertToken(Token token) async {
    await _db.insert('tokens', token.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateToken(Token token) async {
    await _db.update('tokens', token.toMap(), where: 'id = ?', whereArgs: [token.id]);
  }

  Future<void> deleteToken(String id) async {
    await _db.delete('tokens', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateHotpCounter(String tokenId, int newCounter) async {
    await _db.update('tokens', {'counter': newCounter}, where: 'id = ?', whereArgs: [tokenId]);
  }

  // --- Profile CRUD ---

  Future<List<Profile>> getAllProfiles() async {
    final maps = await _db.query('profiles', orderBy: 'sortOrder ASC');
    return maps.map((m) => Profile.fromMap(m)).toList();
  }

  Future<void> insertProfile(Profile profile) async {
    await _db.insert('profiles', profile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProfile(Profile profile) async {
    await _db.update('profiles', profile.toMap(), where: 'id = ?', whereArgs: [profile.id]);
  }

  Future<void> deleteProfile(String id) async {
    await _db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  // --- Group CRUD ---

  Future<List<TokenGroup>> getGroupsByProfile(String profileId) async {
    final maps = await _db.query(
      'groups',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => TokenGroup.fromMap(m)).toList();
  }

  Future<void> insertGroup(TokenGroup group) async {
    await _db.insert('groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteGroup(String id) async {
    await _db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // --- Search ---

  Future<List<Token>> searchTokens(String query) async {
    final maps = await _db.query(
      'tokens',
      where: 'issuer LIKE ? OR account LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'isPinned DESC, issuer ASC',
    );
    return maps.map((m) => Token.fromMap(m)).toList();
  }

  // --- Bulk Operations ---

  Future<void> insertTokens(List<Token> tokens) async {
    final batch = _db.batch();
    for (final token in tokens) {
      batch.insert('tokens', token.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> tokenCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as count FROM tokens');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
