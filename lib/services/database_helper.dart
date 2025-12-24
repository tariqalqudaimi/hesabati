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
      version: 5, // <-- تغيير 1: زدنا رقم الإصدار من 1 إلى 2
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

  // في ملف database_helper.dart
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // نستخدم try-catch لتجاهل الخطأ إذا كان العمود موجوداً مسبقاً
    if (oldVersion < 2) {
      try { await db.execute("ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'SAR'"); } catch (e) {}
    }
    if (oldVersion < 3) {
      try { await db.execute("ALTER TABLE transactions ADD COLUMN imagePath TEXT"); } catch (e) {}
    }
    if (oldVersion < 4) {
      try { await db.execute("ALTER TABLE transactions ADD COLUMN transferId TEXT"); } catch (e) {}
    }
    if (oldVersion < 5) { // <--- تم التحديث ليشمل الإصدارات القديمة
      try { await db.execute("ALTER TABLE transactions ADD COLUMN imagePath TEXT"); } catch (e) {}
      try { await db.execute("ALTER TABLE transactions ADD COLUMN transferId TEXT"); }
      catch (e) {}
    }
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
  // استبدل دالة deleteTransaction القديمة بهذه الجديدة
  Future<void> deleteTransaction(int id) async {
    final db = await database;

    // 1. أولاً: نجلب تفاصيل المعاملة لنعرف هل لها transferId أم لا
    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      columns: ['transferId'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      final String? transferId = result.first['transferId'] as String?;

      if (transferId != null && transferId.isNotEmpty) {
        // 2. إذا كانت حوالة، نحذف كل العمليات المرتبطة بهذا الرقم
        await db.delete(
          'transactions',
          where: 'transferId = ?',
          whereArgs: [transferId],
        );
      } else {
        // 3. إذا كانت عملية عادية، نحذفها هي فقط
        await db.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
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

    // إنشاء رقم عملية فريد يربط العمليتين ببعضهما
    // نستخدم الوقت الحالي كرقم مميز
    final String transferId = "TR-${DateTime.now().millisecondsSinceEpoch}";

    await db.transaction((txn) async {
      final date = DateTime.now().toIso8601String();

      // 1. خصم من المرسل
      await txn.insert('transactions', {
        'personId': fromPersonId,
        'type': 'مصروف',
        'amount': amount,
        'description': 'تحويل إلى: $toPersonName ($description)',
        'date': date,
        'currency': currency,
        'transferId': transferId, // <-- الرابط
      });

      // 2. إضافة للمستلم
      await txn.insert('transactions', {
        'personId': toPersonId,
        'type': 'إيراد',
        'amount': amount,
        'description': 'حوالة من: $fromPersonName ($description)',
        'date': date,
        'currency': currency,
        'transferId': transferId, // <-- نفس الرابط
      });
    });
  }

}