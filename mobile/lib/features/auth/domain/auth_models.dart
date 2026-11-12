class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.baseCurrency,
    required this.timezone,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      baseCurrency: (json['baseCurrency'] ?? 'THB').toString(),
      timezone: (json['timezone'] ?? 'Asia/Bangkok').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String baseCurrency;
  final String timezone;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'displayName': displayName,
      'baseCurrency': baseCurrency,
      'timezone': timezone,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? baseCurrency,
    String? timezone,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
    required this.refreshTokenExpiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      accessTokenExpiresIn:
          (json['accessTokenExpiresIn'] as num?)?.toInt() ?? 900,
      refreshTokenExpiresAt:
          DateTime.tryParse((json['refreshTokenExpiresAt'] ?? '').toString()) ??
          DateTime.now().add(const Duration(days: 30)),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresIn;
  final DateTime refreshTokenExpiresAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresIn': accessTokenExpiresIn,
      'refreshTokenExpiresAt': refreshTokenExpiresAt.toUtc().toIso8601String(),
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.tokens,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: User.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      tokens: AuthTokens.fromJson(
        (json['tokens'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }

  final User user;
  final AuthTokens tokens;
}

class AuthStatus {
  const AuthStatus({required this.registrationOpen});

  factory AuthStatus.fromJson(Map<String, dynamic> json) {
    return AuthStatus(
      registrationOpen: json['registrationOpen'] == true,
    );
  }

  final bool registrationOpen;
}

class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.uptime,
    required this.version,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: (json['status'] ?? 'ok').toString(),
      uptime: (json['uptime'] as num?)?.toDouble() ?? 0.0,
      version: (json['version'] ?? '1.0.0').toString(),
    );
  }

  final String status;
  final double uptime;
  final String version;
}
