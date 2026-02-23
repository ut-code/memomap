class User {
  final String id;
  final String email;
  final String name;
  final String? image;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.image,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      emailVerified: json['emailVerified'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class Session {
  final String id;
  final String userId;
  final DateTime expiresAt;

  Session({
    required this.id,
    required this.userId,
    required this.expiresAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      userId: json['userId'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class SessionResponse {
  final Session session;
  final User user;

  SessionResponse({
    required this.session,
    required this.user,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      session: Session.fromJson(json['session'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  factory SessionResponse.fromJwtPayload(Map<String, dynamic> payload) {
    final exp = payload['exp'] as int?;
    final sub = payload['sub'] as String;
    final email = payload['email'] as String? ?? '';

    return SessionResponse(
      session: Session(
        id: 'jwt',
        userId: sub,
        expiresAt: exp != null
            ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
            : DateTime.now().add(const Duration(hours: 1)),
      ),
      user: User(
        id: sub,
        email: email,
        name: email.split('@').first,
        emailVerified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
