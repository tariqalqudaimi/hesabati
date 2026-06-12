import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/person_model.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';

// 1. مزود للوصول إلى قاعدة البيانات (يبقى كما هو)
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

// 2. مزود لجلب قائمة الأشخاص (يبقى كما هو)
final personsProvider = FutureProvider<List<Person>>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return dbHelper.getPersons();
});

// 3. مزود لجلب معاملات شخص معين (يبقى كما هو)
final transactionsProvider = FutureProvider.family<List<Transaction>, int>((ref, personId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return dbHelper.getTransactions(personId);
});

// 4. مزود لجلب رصيد شخص معين لعملة معينة (يبقى كما هو)
class BalanceParams {
  final int personId;
  final String currency;
  BalanceParams({required this.personId, required this.currency});
  @override
  bool operator ==(Object other) => other is BalanceParams && personId == other.personId && currency == other.currency;
  @override
  int get hashCode => personId.hashCode ^ currency.hashCode;
}

final balanceProvider = FutureProvider.family<double, BalanceParams>((ref, params) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return dbHelper.getBalance(params.personId, params.currency);
});


// 5. Provider الإجمالي الكلي (الكود الجديد والصحيح والمبسط)
final totalBalanceProvider = FutureProvider.family<double, String>((ref, currency) async {
  // --- هذا هو التغيير الجوهري ---
  // أولاً، انتظر حتى تكتمل نتيجة `personsProvider` واحصل على القائمة مباشرة.
  // إذا كان `personsProvider` في حالة تحميل، فإن هذا السطر سينتظر تلقائيًا.
  // إذا كان في حالة خطأ، فسيتم طرح الخطأ هنا وسيتعامل Riverpod معه.
  final persons = await ref.watch(personsProvider.future);

  // إذا لم يكن هناك أشخاص، فالإجمالي هو صفر.
  if (persons.isEmpty) {
    return 0.0;
  }

  final dbHelper = ref.watch(databaseHelperProvider);

  // استخدم Future.wait لجلب كل الأرصدة بالتوازي لزيادة السرعة
  final List<Future<double>> balanceFutures = persons.map((person) {
    return dbHelper.getBalance(person.id!, currency);
  }).toList();

  final List<double> balances = await Future.wait(balanceFutures);

  // اجمع كل الأرصدة للحصول على الإجمالي النهائي
  return balances.isEmpty ? 0.0 : balances.reduce((value, element) => value + element);
});

// ... في ملف database_providers.dart

// Provider جديد: يحسب إجمالي الأموال الموجودة في الخزائن والبنوك لعملة معينة
final totalWalletsBalanceProvider = FutureProvider.family<double, String>((ref, currency) async {
  final dbHelper = ref.watch(databaseHelperProvider);

  // 1. جلب كل الخزائن
  final wallets = await dbHelper.getWallets();

  // 2. تصفية حسب العملة
  final filteredWallets = wallets.where((w) => w.currency == currency);

  double total = 0.0;

  // 3. جمع أرصدة الخزائن
  for (var w in filteredWallets) {
    total += await dbHelper.getWalletBalance(w.id!);
  }

  return total;
});