import 'package:uuid/uuid.dart';

enum OtpType { totp, hotp }

enum Algorithm { sha1, sha256, sha512 }

class Token {
  final String id;
  final String issuer;
  final String account;
  final String secret;
  final OtpType type;
  final Algorithm algorithm;
  final int digits;
  final int period; // TOTP only (seconds)
  final int counter; // HOTP only
  final String? iconPath;
  final String? profileId;
  final String? groupId;
  final List<String> tags;
  final bool isPinned;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Token({
    String? id,
    required this.issuer,
    required this.account,
    required this.secret,
    this.type = OtpType.totp,
    this.algorithm = Algorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
    this.iconPath,
    this.profileId,
    this.groupId,
    this.tags = const [],
    this.isPinned = false,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Token copyWith({
    String? issuer,
    String? account,
    String? secret,
    OtpType? type,
    Algorithm? algorithm,
    int? digits,
    int? period,
    int? counter,
    String? iconPath,
    String? profileId,
    String? groupId,
    List<String>? tags,
    bool? isPinned,
    int? sortOrder,
  }) {
    return Token(
      id: id,
      issuer: issuer ?? this.issuer,
      account: account ?? this.account,
      secret: secret ?? this.secret,
      type: type ?? this.type,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      counter: counter ?? this.counter,
      iconPath: iconPath ?? this.iconPath,
      profileId: profileId ?? this.profileId,
      groupId: groupId ?? this.groupId,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'issuer': issuer,
      'account': account,
      'secret': secret,
      'type': type.name,
      'algorithm': algorithm.name,
      'digits': digits,
      'period': period,
      'counter': counter,
      'iconPath': iconPath,
      'profileId': profileId,
      'groupId': groupId,
      'tags': tags.join(','),
      'isPinned': isPinned ? 1 : 0,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Token.fromMap(Map<String, dynamic> map) {
    return Token(
      id: map['id'] as String,
      issuer: map['issuer'] as String,
      account: map['account'] as String,
      secret: map['secret'] as String,
      type: OtpType.values.byName(map['type'] as String),
      algorithm: Algorithm.values.byName(map['algorithm'] as String),
      digits: map['digits'] as int,
      period: map['period'] as int,
      counter: map['counter'] as int,
      iconPath: map['iconPath'] as String?,
      profileId: map['profileId'] as String?,
      groupId: map['groupId'] as String?,
      tags: (map['tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      isPinned: (map['isPinned'] as int) == 1,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Parse otpauth:// URI
  factory Token.fromUri(String uri) {
    final parsed = Uri.parse(uri);
    if (parsed.scheme != 'otpauth') {
      throw FormatException('Invalid OTP URI scheme: ${parsed.scheme}');
    }

    final type = parsed.host == 'hotp' ? OtpType.hotp : OtpType.totp;
    final params = parsed.queryParameters;

    // Path is /issuer:account or /account
    var path = Uri.decodeFull(parsed.path);
    if (path.startsWith('/')) path = path.substring(1);

    String issuer;
    String account;
    if (path.contains(':')) {
      final parts = path.split(':');
      issuer = parts[0];
      account = parts.sublist(1).join(':');
    } else {
      issuer = params['issuer'] ?? '';
      account = path;
    }

    // Override issuer from params if present
    if (params.containsKey('issuer')) {
      issuer = params['issuer']!;
    }

    final secret = params['secret'];
    if (secret == null || secret.isEmpty) {
      throw const FormatException('Missing secret in OTP URI');
    }

    return Token(
      issuer: issuer,
      account: account,
      secret: secret.toUpperCase(),
      type: type,
      algorithm: _parseAlgorithm(params['algorithm']),
      digits: int.tryParse(params['digits'] ?? '') ?? 6,
      period: int.tryParse(params['period'] ?? '') ?? 30,
      counter: int.tryParse(params['counter'] ?? '') ?? 0,
    );
  }

  String toUri() {
    final typeName = type == OtpType.hotp ? 'hotp' : 'totp';
    final label = issuer.isNotEmpty ? '$issuer:$account' : account;
    final params = <String, String>{
      'secret': secret,
      'issuer': issuer,
      'algorithm': algorithm.name.toUpperCase(),
      'digits': digits.toString(),
    };
    if (type == OtpType.totp) {
      params['period'] = period.toString();
    } else {
      params['counter'] = counter.toString();
    }
    return Uri(
      scheme: 'otpauth',
      host: typeName,
      path: '/$label',
      queryParameters: params,
    ).toString();
  }

  static Algorithm _parseAlgorithm(String? value) {
    switch (value?.toUpperCase()) {
      case 'SHA256':
        return Algorithm.sha256;
      case 'SHA512':
        return Algorithm.sha512;
      default:
        return Algorithm.sha1;
    }
  }
}
