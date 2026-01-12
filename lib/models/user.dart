class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse bool
    bool _parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is int) return value != 0;
      return false;
    }

    // Helper function to safely parse string
    String _parseString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    // Helper function to safely parse DateTime
    DateTime? _parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return User(
      id: _parseString(json['id']),
      email: _parseString(json['email']),
      name: _parseString(json['name']),
      role: _parseString(json['role']),
      isActive: _parseBool(json['is_active'] ?? json['isActive'] ?? false),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']) ?? DateTime.now(),
      lastLogin: _parseDateTime(json['last_login'] ?? json['lastLogin']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
