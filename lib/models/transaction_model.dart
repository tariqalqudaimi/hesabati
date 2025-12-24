class Transaction {
  final int? id;
  final int personId;
  final String type;
  final double amount;
  final String description;
  final String date;
  final String currency;
  final String? imagePath;
  final String? transferId;

  final int? walletId; // <-- الحقل الجديد لربط الحوالات


  Transaction({
    this.id,
    required this.personId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.currency,
    this.imagePath,
    this.transferId, this.walletId, // <-- أضفه هنا
  });

  // تحديث toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
      'currency': currency,
      'imagePath': imagePath,
      'transferId': transferId,
      'walletId':walletId
    };
  }

  // تحديث fromMap
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      personId: map['personId'],
      type: map['type'],
      amount: map['amount'],
      description: map['description'],
      date: map['date'],
      currency: map['currency'],
      imagePath: map['imagePath'],
      transferId: map['transferId'],
      walletId: map['walletId'],
    );
  }

  // تحديث copyWith
  Transaction copyWith({
    int? id,
    int? personId,
    String? type,
    double? amount,
    String? description,
    String? date,
    String? currency,
    String? imagePath,
    String? transferId, // <-- أضفه هنا
    int? walletId
  }) {
    return Transaction(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      currency: currency ?? this.currency,
      imagePath: imagePath ?? this.imagePath,
      transferId: transferId ?? this.transferId, // <-- أضفه هنا
      walletId: walletId ?? this.walletId,

    );
  }
}