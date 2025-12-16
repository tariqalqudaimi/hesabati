import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart'; // نحتاج هذه الحزمة لمعرفة إصدار الأندرويد
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/transaction_model.dart';
import '../models/person_model.dart';

class ExportService {

  // --- دالة ذكية لطلب الصلاحية حسب إصدار الأندرويد ---
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      // إذا كان أندرويد 11 (SDK 30) أو أحدث
      if (androidInfo.version.sdkInt >= 30) {
        // نطلب صلاحية "الوصول لكل الملفات"
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // إذا كان أندرويد 10 أو أقدم
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true; // للـ iOS لا نحتاج هذا التعقيد غالباً
  }

  // --- دالة الحصول على المسار ---
  Future<String?> _getDownloadPath() async {
    Directory? directory;
    try {
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (err) {
      print("Error getting path: $err");
    }
    return directory?.path;
  }

  // ---------------------------------------------------------
  // 1. النسخ الاحتياطي
  // ---------------------------------------------------------
  Future<String> backupDatabase() async {
    // التحقق من الصلاحية أولاً
    if (!await _requestPermission()) {
      throw Exception("يجب منح صلاحية الوصول للملفات لحفظ النسخة");
    }

    var dbPath = await getDatabasesPath();
    String currentPath = p.join(dbPath, 'hesabati.db');
    File sourceFile = File(currentPath);

    if (!await sourceFile.exists()) {
      throw Exception("قاعدة البيانات غير موجودة");
    }

    String downloadPath = await _getDownloadPath() ?? "";
    String fileName = 'hesabati_backup_${DateTime.now().millisecondsSinceEpoch}.db';
    String newPath = '$downloadPath/$fileName';

    await sourceFile.copy(newPath);
    return newPath;
  }

  // ---------------------------------------------------------
  // 2. تصدير Excel
  // ---------------------------------------------------------
  Future<String> exportToExcel(Person person, List<Transaction> transactions) async {
    if (!await _requestPermission()) {
      throw Exception("يجب منح صلاحية الوصول للملفات");
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];
    sheet.isRTL = true;

    sheet.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('الوصف'),
      TextCellValue('النوع'),
      TextCellValue('المبلغ'),
      TextCellValue('العملة')
    ]);

    for (var t in transactions) {
      sheet.appendRow([
        TextCellValue(t.date.split('T')[0]),
        TextCellValue(t.description),
        TextCellValue(t.type),
        DoubleCellValue(t.amount),
        TextCellValue(t.currency),
      ]);
    }

    String downloadPath = await _getDownloadPath() ?? "";
    String fileName = 'كشف_${person.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    String fullPath = '$downloadPath/$fileName';

    var fileBytes = excel.save();
    File(fullPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    return fullPath;
  }

  // ---------------------------------------------------------
  // 3. تصدير PDF
  // ---------------------------------------------------------
  Future<String> exportToPdf(Person person, List<Transaction> transactions) async {
    if (!await _requestPermission()) {
      throw Exception("يجب منح صلاحية الوصول للملفات");
    }

    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // ... (باقي كود حساب المجاميع كما هو في الإجابة السابقة) ...
    // سأختصر هنا لتوفير المساحة، انسخ كود الـ PDF السابق وضعه هنا
    // الكود السابق لحساب المجاميع وبناء الجدول ممتاز.

    // حساب المجاميع (سريعاً)
    double totalSarIncome = 0;
    double totalSarExpense = 0;
    double totalYerIncome = 0;
    double totalYerExpense = 0;
    for(var t in transactions) {
      if(t.currency == 'SAR') {
        if(t.type == 'إيراد') totalSarIncome += t.amount; else totalSarExpense += t.amount;
      } else {
        if(t.type == 'إيراد') totalYerIncome += t.amount; else totalYerExpense += t.amount;
      }
    }

    pdf.addPage(
        pw.MultiPage(
            theme: pw.ThemeData.withFont(base: ttf),
            textDirection: pw.TextDirection.rtl,
            build: (pw.Context context) {
              return [
                pw.Header(level: 0, child: pw.Center(child: pw.Text("كشف حساب: ${person.name}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)))),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['العملة', 'إيراد', 'مصروف', 'الصافي'],
                  data: [
                    ['SAR', totalSarIncome.toStringAsFixed(2), totalSarExpense.toStringAsFixed(2), (totalSarIncome - totalSarExpense).toStringAsFixed(2)],
                    ['YER', totalYerIncome.toStringAsFixed(2), totalYerExpense.toStringAsFixed(2), (totalYerIncome - totalYerExpense).toStringAsFixed(2)],
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['التاريخ', 'الوصف', 'النوع', 'العملة', 'المبلغ'],
                  data: transactions.map((t) => [
                    t.date.split('T')[0],
                    t.description,
                    t.type,
                    t.currency,
                    t.amount.toStringAsFixed(2),
                  ]).toList(),
                ),
              ];
            }
        )
    );

    String downloadPath = await _getDownloadPath() ?? "";
    String fileName = 'كشف_${person.name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    String fullPath = '$downloadPath/$fileName';

    final file = File(fullPath);
    await file.writeAsBytes(await pdf.save());

    return fullPath;
  }
}