class Wallet {
  final int? id;
  final String name; // مثال: "الخزنة الرئيسية"، "بنك الراجحي"
  final String currency; // SAR, YER
  final double initialBalance; // الرصيد الافتتاحي

  Wallet({this.id, required this.name, required this.currency, required this.initialBalance});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'currency': currency, 'initialBalance': initialBalance};
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'],
      name: map['name'],
      currency: map['currency'],
      initialBalance: map['initialBalance'],
    );
  }
}