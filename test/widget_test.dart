import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/models/profile.dart';

void main() {
  test('Token model serialization round-trip', () {
    final token = Token(
      issuer: 'GitHub',
      account: 'user@test.com',
      secret: 'JBSWY3DPEHPK3PXP',
      tags: ['work', 'dev'],
      isPinned: true,
    );

    final map = token.toMap();
    final restored = Token.fromMap(map);

    expect(restored.id, token.id);
    expect(restored.issuer, 'GitHub');
    expect(restored.account, 'user@test.com');
    expect(restored.secret, 'JBSWY3DPEHPK3PXP');
    expect(restored.tags, ['work', 'dev']);
    expect(restored.isPinned, true);
  });

  test('Profile model serialization round-trip', () {
    final profile = Profile(
      name: 'Work',
      colorValue: 0xFF6366F1,
    );

    final map = profile.toMap();
    final restored = Profile.fromMap(map);

    expect(restored.id, profile.id);
    expect(restored.name, 'Work');
    expect(restored.colorValue, 0xFF6366F1);
  });
}
