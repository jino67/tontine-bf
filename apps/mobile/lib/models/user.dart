// user.dart
class User {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final bool isVerified;

  User({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Fonction helper pour gérer les différents types de 'is_verified'
    bool _parseIsVerified(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'true';
      return false;
    }

    // 🔥 CORRECTION APPLIQUÉE : Chercher l'ID sous différents noms si le premier est null
    final dynamic rawId = json['id'] ?? json['user_id'];
    final String safeId = rawId?.toString() ?? '';

    return User(
      id: safeId,
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      isVerified: _parseIsVerified(json['is_verified']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'email': email,
      'is_verified': isVerified ? 1 : 0,
    };
  }
}