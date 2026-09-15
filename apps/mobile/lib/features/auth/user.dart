import '../../core/json.dart';

class User {
  const User({required this.id, required this.phone, this.name, this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: asInt(json['id']),
        phone: '${json['phone'] ?? ''}',
        name: asStringOrNull(json['name']),
        email: asStringOrNull(json['email']),
      );

  final int id;
  final String phone;
  final String? name;
  final String? email;

  String get firstName => (name ?? '').trim().split(RegExp(r'\s+')).first;
}
