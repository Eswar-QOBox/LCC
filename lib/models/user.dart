class User {
  final String id;
  final String login; // JHipster login = phone digits for JSEE customers
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.login,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    bool _parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      if (value is int) return value != 0;
      return false;
    }

    String _parseString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    DateTime? _parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // JHipster /api/account returns: { id, login, firstName, lastName, email, activated, authorities: [...] }
    // Old backend returns:           { id, name, email, role, is_active, created_at, updated_at }
    // Support both so the model works with either format.

    // Name: prefer full 'name', else build from JHipster firstName + lastName
    String name;
    if (json['name'] != null) {
      name = _parseString(json['name']);
    } else {
      final firstName = _parseString(json['firstName'] ?? json['first_name']);
      final lastName = _parseString(json['lastName'] ?? json['last_name']);
      name = '$firstName $lastName'.trim();
    }

    // Role: prefer 'role', else derive from JHipster authorities array
    String role;
    if (json['role'] != null) {
      role = _parseString(json['role']);
    } else {
      final authorities = json['authorities'];
      if (authorities is List && authorities.isNotEmpty) {
        // e.g. "ROLE_ADMIN" → "admin"
        role = authorities.first.toString().replaceFirst('ROLE_', '').toLowerCase();
      } else {
        role = 'user';
      }
    }

    // ID: JHipster uses integer id; old backend uses string
    final rawId = json['id'];
    final id = rawId != null ? rawId.toString() : '';

    // Login: JHipster username (= phone digits for JSEE customers)
    final login = _parseString(json['login'] ?? json['username'] ?? '');

    // Active: JHipster uses 'activated'
    final isActive = _parseBool(
      json['activated'] ?? json['is_active'] ?? json['isActive'] ?? true,
    );

    return User(
      id: id,
      login: login,
      email: _parseString(json['email']),
      name: name,
      role: role,
      isActive: isActive,
      createdAt: _parseDateTime(json['createdDate'] ?? json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['lastModifiedDate'] ?? json['updated_at'] ?? json['updatedAt']) ?? DateTime.now(),
      lastLogin: _parseDateTime(json['last_login'] ?? json['lastLogin']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'email': email,
      'name': name,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? login,
    String? email,
    String? name,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      login: login ?? this.login,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
