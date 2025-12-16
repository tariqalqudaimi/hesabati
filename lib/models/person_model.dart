class Person {
  final int? id;
  final String name;

  Person({this.id, required this.name});

  // لتحويل بيانات الكلاس إلى Map لإدخالها في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}