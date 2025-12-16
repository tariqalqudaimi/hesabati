class Transaction {
  final int? id;
  final int personId;
  final String type;
  final double amount;
  final String description;
  final String date;
  final String currency;

  Transaction({
    this.id,
    required this.personId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.currency,
  });

  // --- دالة جديدة ---
  Transaction copyWith({
    int? id,
    int? personId,
    String? type,
    double? amount,
    String? description,
    String? date,
    String? currency,
  }) {
    return Transaction(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
      'currency': currency,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      personId: map['personId'],
      type: map['type'],
      amount: map['amount'],
      description: map['description'],
      date: map['date'],
      currency: map['currency'],
    );
  }
}