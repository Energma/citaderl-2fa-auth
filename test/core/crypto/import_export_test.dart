import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/crypto/import_export.dart';
import 'package:citadel_auth/core/models/token.dart';

void main() {
  group('ImportExport - Citadel format', () {
    test('round-trip export/import preserves tokens', () {
      final tokens = [
        Token(
          issuer: 'GitHub',
          account: 'user@test.com',
          secret: 'JBSWY3DPEHPK3PXP',
          algorithm: Algorithm.sha1,
          digits: 6,
          period: 30,
        ),
        Token(
          issuer: 'AWS',
          account: 'admin',
          secret: 'GEZDGNBVGY3TQOJQ',
          algorithm: Algorithm.sha256,
          digits: 8,
          period: 60,
        ),
      ];

      final exported = ImportExport.exportToJson(tokens);
      final imported = ImportExport.importFromJson(exported);

      expect(imported.length, 2);
      expect(imported[0].issuer, 'GitHub');
      expect(imported[0].secret, 'JBSWY3DPEHPK3PXP');
      expect(imported[1].issuer, 'AWS');
      expect(imported[1].digits, 8);
    });
  });

  group('ImportExport - Aegis format', () {
    test('imports Aegis JSON export', () {
      final aegisData = json.encode({
        'version': 2,
        'db': {
          'entries': [
            {
              'type': 'totp',
              'name': 'user@gmail.com',
              'issuer': 'Google',
              'info': {
                'secret': 'JBSWY3DPEHPK3PXP',
                'algo': 'SHA1',
                'digits': 6,
                'period': 30,
              },
            },
          ],
        },
      });

      final tokens = ImportExport.importFromJson(aegisData);
      expect(tokens.length, 1);
      expect(tokens[0].issuer, 'Google');
      expect(tokens[0].account, 'user@gmail.com');
    });
  });

  group('ImportExport - URI list', () {
    test('imports otpauth URI list', () {
      const uris = '''
otpauth://totp/GitHub:user@test.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
otpauth://totp/Google:user@gmail.com?secret=GEZDGNBVGY3TQOJQ&issuer=Google
''';
      final tokens = ImportExport.importFromJson(uris);
      expect(tokens.length, 2);
      expect(tokens[0].issuer, 'GitHub');
      expect(tokens[1].issuer, 'Google');
    });
  });

  group('ImportExport - URI export', () {
    test('exports as otpauth URI list', () {
      final tokens = [
        Token(
          issuer: 'GitHub',
          account: 'user@test.com',
          secret: 'JBSWY3DPEHPK3PXP',
        ),
      ];

      final uris = ImportExport.exportToUriList(tokens);
      expect(uris, contains('otpauth://totp/'));
      expect(uris, contains('JBSWY3DPEHPK3PXP'));
    });
  });
}
