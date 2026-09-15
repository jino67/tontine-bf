class Wallet {
  final String id;
  final String userId;
  final double balance;
  final String phoneNumber; // Numéro Orange Money
  final DateTime createdAt;
  final DateTime updatedAt;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'],
      userId: json['user_id'],
      balance: (json['balance'] as num).toDouble(),
      phoneNumber: json['phone_number'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class Transaction {
  final String id;
  final String walletId;
  final String type; // 'deposit', 'withdrawal', 'payment', 'receipt'
  final double amount;
  final String description;
  final String status; // 'pending', 'completed', 'failed'
  final String? reference;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    this.reference,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      walletId: json['wallet_id'],
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      status: json['status'],
      reference: json['reference'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'description': description,
      'status': status,
      'reference': reference,
      'created_at': createdAt.toIso8601String(),
    };
  }
}