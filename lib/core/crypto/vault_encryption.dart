import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Handles vault encryption using Argon2id for key derivation and AES-256-GCM for encryption.
class VaultEncryption {
  static const int _saltLength = 32;
  static const int _nonceLength = 12; // AES-GCM standard

  /// Derive an encryption key from a master password using Argon2id.
  static Future<SecretKey> deriveKey(String password, Uint8List salt) async {
    final argon2 = Argon2id(
      parallelism: 4,
      memory: 65536, // 64 MB
      iterations: 3,
      hashLength: 32, // 256-bit key
    );

    return argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Generate a random salt.
  static Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  /// Encrypt data with AES-256-GCM.
  static Future<Uint8List> encrypt(Uint8List plaintext, SecretKey key) async {
    final algo = AesGcm.with256bits();
    final nonce = algo.newNonce();

    final secretBox = await algo.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );

    // Format: nonce (12) + ciphertext + mac (16)
    final result = Uint8List(nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length);
    var offset = 0;
    result.setRange(offset, offset + nonce.length, nonce);
    offset += nonce.length;
    result.setRange(offset, offset + secretBox.cipherText.length, secretBox.cipherText);
    offset += secretBox.cipherText.length;
    result.setRange(offset, offset + secretBox.mac.bytes.length, secretBox.mac.bytes);
    return result;
  }

  /// Decrypt data with AES-256-GCM.
  static Future<Uint8List> decrypt(Uint8List ciphertext, SecretKey key) async {
    final algo = AesGcm.with256bits();

    final nonce = ciphertext.sublist(0, _nonceLength);
    final mac = Mac(ciphertext.sublist(ciphertext.length - 16));
    final encrypted = ciphertext.sublist(_nonceLength, ciphertext.length - 16);

    final secretBox = SecretBox(
      encrypted,
      nonce: nonce,
      mac: mac,
    );

    final plaintext = await algo.decrypt(secretBox, secretKey: key);
    return Uint8List.fromList(plaintext);
  }

  /// Encrypt a string and return Base64-encoded result.
  static Future<String> encryptString(String plaintext, SecretKey key) async {
    final encrypted = await encrypt(Uint8List.fromList(utf8.encode(plaintext)), key);
    return base64.encode(encrypted);
  }

  /// Decrypt a Base64-encoded string.
  static Future<String> decryptString(String ciphertext, SecretKey key) async {
    final decrypted = await decrypt(Uint8List.fromList(base64.decode(ciphertext)), key);
    return utf8.decode(decrypted);
  }
}
