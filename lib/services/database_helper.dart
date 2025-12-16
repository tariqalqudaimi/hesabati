import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/person_model.dart';
import '../models/transaction_model.dart';
import '../providers/database_providers.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'hesabati.db');
    return await openDatabase(
      path,
      version: 2, // <-- تغيير 1: زدنا رقم الإصدار من 1 إلى 2
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // <-- تغيير 2: أضفنا دالة الترقية
    );
  }

  // هذه الدالة تُستدعى فقط عند إنشاء قاعدة البيانات لأول مرة
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    // سنضيف حقل العملة هنا مباشرة للمستخدمين الجدد
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        personId INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        currency TEXT NOT NULL 
      )
    ''');
  }

  // <-- تغيير 3: هذه هي الدالة الجديدة والمهمة جداً
  // تُستدعى فقط عندما يتغير رقم الإصدار (مثلاً من 1 إلى 2)
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // نستخدم if للتحقق من الإصدار القديم
    // هذا مفيد جدًا للترقيات المستقبلية
    if (oldVersion < 2) {
      // المستخدم كان على الإصدار 1 ونريد ترقيته للإصدار 2
      // الأمر التالي يضيف عمود 'currency' إلى جدول 'transactions'
      // ونعطيه قيمة افتراضية 'SAR' لكل البيانات القديمة حتى لا يحدث خطأ
      await db.execute("ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'SAR'");
    }

    // إذا كان لديك ترقية مستقبلية للإصدار 3، ستضيف:
    // if (oldVersion < 3) {
    //   // أوامر الترقية للإصدار 3
    // }
  }

  // --- دوال الأشخاص ---
  Future<int> addPerson(Person person) async {
    Database db = await database;
    return await db.insert('persons', person.toMap());
  }

  Future<List<Person>> getPersons() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('persons');
    return List.generate(maps.length, (i) {
      return Person(id: maps[i]['id'], name: maps[i]['name']);
    });
  }

  // --- دوال المعاملات (الجديدة) ---

  // إضافة معاملة جديدة
  Future<int> addTransaction(Transaction transaction) async {
    Database db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  // جلب كل معاملات شخص معين
  Future<List<Transaction>> getTransactions(int personId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'personId = ?',
      whereArgs: [personId],
      orderBy: 'date DESC', // ترتيبها من الأحدث للأقدم
    );

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<double> getBalance(int personId, String currency) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      columns: ['type', 'amount'],
      where: 'personId = ? AND currency = ?', // <-- تعديل الشرط هنا
      whereArgs: [personId, currency],
    );

    double balance = 0.0;
    for (var map in maps) {
      if (map['type'] == 'إيراد') {
        balance += map['amount'];
      } else {
        balance -= map['amount'];
      }
    }
    return balance;
  }
// ... داخل كلاس DatabaseHelper

// دالة لحذف معاملة
  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// دالة لجلب مجاميع الإيرادات والمصروفات (للمخطط البياني)
  Future<Map<String, double>> getCategoryTotals(int personId, String currency) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      columns: ['type', 'amount'],
      where: 'personId = ? AND currency = ?',
      whereArgs: [personId, currency],
    );

    double income = 0.0;
    double expense = 0.0;

    for (var map in maps) {
      if (map['type'] == 'إيراد') {
        income += map['amount'];
      } else {
        expense += map['amount'];
      }
    }
    return {'income': income, 'expense': expense};
  }
  // ... داخل كلاس DatabaseHelper

// دالة لتحديث معاملة
  Future<void> updateTransaction(Transaction transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }


  Future<void> updatePerson(Person person) async {
    final db = await database;
    await db.update('persons', person.toMap(), where: 'id = ?', whereArgs: [person.id]);
  }

  Future<void> deletePerson(int id) async {
    final db = await database;
    // سيقوم بحذف الشخص وكل معاملاته المرتبطة به تلقائيًا بفضل ON DELETE CASCADE
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  final totalBalanceProvider = FutureProvider.family<double, String>((ref, currency) async {
    final dbHelper = ref.watch(databaseHelperProvider);
    // استدعاء provider آخر لجلب الأشخاص المحدثين
    final persons = await ref.watch(personsProvider.future);
    double total = 0.0;

    // المرور على كل شخص وحساب رصيده لهذه العملة
    for (final person in persons) {
      total += await dbHelper.getBalance(person.id!, currency);
    }

    return total;
  });

  // --- دالة التحويل المالي ---
  Future<void> transferMoney({
    required int fromPersonId,
    required String fromPersonName,
    required int toPersonId,
    required String toPersonName,
    required double amount,
    required String currency,
    required String description,
  }) async {
    final db = await database;

    // نستخدم transaction لضمان تنفيذ العمليتين معاً أو فشلهما معاً (أمان مالي)
    await db.transaction((txn) async {
      final date = DateTime.now().toIso8601String();

      // 1. خصم من المرسل (مصروف)
      await txn.insert('transactions', {
        'personId': fromPersonId,
        'type': 'مصروف',
        'amount': amount,
        'description': 'تحويل إلى: $toPersonName ($description)',
        'date': date,
        'currency': currency,
      });

      // 2. إضافة للمستلم (إيراد)
      await txn.insert('transactions', {
        'personId': toPersonId,
        'type': 'إيراد',
        'amount': amount,
        'description': 'حوالة من: $fromPersonName ($description)',
        'date': date,
        'currency': currency,
      });
    });
  }

}