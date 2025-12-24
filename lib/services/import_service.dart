import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../models/transaction_model.dart';
import '../providers/database_providers.dart';

class ImportService {

  // 1. دالة لتحويل الأرقام العربية (١٢٣) إلى إنجليزية (123)
  String _normalizeArabicNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  // 2. دالة لاستخراج رقم الشهر من الاسم (عربي أو إنجليزي)
  int _getMonthNumber(String monthName) {
    // تنظيف النص
    String key = monthName.trim().replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');

    const months = {
      // العربية
      'يناير': 1, 'فبراير': 2, 'مارس': 3, 'أبريل': 4, 'ابريل': 4, 'مايو': 5, 'يونيو': 6,
      'يوليو': 7, 'أغسطس': 8, 'اغسطس': 8, 'سبتمبر': 9, 'أكتوبر': 10, 'اكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
      // الشامية/العراقية
      'كانون الثاني': 1, 'شباط': 2, 'آذار': 3, 'ازار': 3, 'نيسان': 4, 'أيار': 5, 'ايار': 5, 'حزيران': 6,
      'تموز': 7, 'آب': 8, 'اب': 8, 'أيلول': 9, 'ايلول': 9, 'تشرين الأول': 10, 'تشرين الاول': 10, 'تشرين الثاني': 11, 'كانون الأول': 12, 'كانون الاول': 12,
      // الإنجليزية (اختصارات وكاملة)
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
    };

    for (var m in months.keys) {
      if (key.toLowerCase().contains(m)) return months[m]!;
    }
    return 0; // لم يتم العثور على شهر
  }

  // 3. الدالة الذكية لتحليل التاريخ
  String _parseDate(dynamic rawValue) {
    if (rawValue == null) return DateTime.now().toIso8601String();

    try {
      // أ) معالجة تواريخ إكسل الرقمية
      if (rawValue is int || rawValue is double) {
        int days = rawValue is int ? rawValue : (rawValue as double).toInt();
        return DateTime.fromMillisecondsSinceEpoch((days - 25569) * 86400000).toIso8601String();
      }

      String dateStr = rawValue.toString();

      // ب) تحويل الأرقام العربية إلى إنجليزية (الحل لمشكلتك)
      dateStr = _normalizeArabicNumbers(dateStr);

      // ج) تنظيف النص من الوقت والرموز الزائدة
      // مثال الدخل: "15-ديسمبر-2025 01:18 ص" -> نأخذ فقط التاريخ إذا وجدنا فواصل
      // نستبدل أي فاصل غير رقمي أو حرفي بمسافة لسهولة التقسيم
      // ولكن نحافظ على الأحرف (لأسماء الأشهر)

      // نقسم النص لنبحث عن الأجزاء
      List<String> parts = dateStr.split(RegExp(r'[\s\-\/\.,:،]+')); // تقسيم بناء على المسافة، الشرطة، النقطة، إلخ

      int? day;
      int? month;
      int? year;

      for (var part in parts) {
        if (part.isEmpty) continue;

        // هل هو رقم؟
        if (RegExp(r'^\d+$').hasMatch(part)) {
          int val = int.parse(part);

          // تخمين السنة (4 خانات)
          if (val > 1900 && val < 2100) {
            year = val;
          }
          // تخمين اليوم (1-31)
          else if (val >= 1 && val <= 31 && day == null) {
            // ملاحظة: قد يحدث تداخل بين اليوم والشهر الرقمي، سنفترض الأول هو اليوم
            day = val;
          }
          // تخمين الشهر الرقمي (1-12)
          else if (val >= 1 && val <= 12 && month == null) {
            month = val;
          }
        }
        // هل هو اسم شهر؟
        else {
          int m = _getMonthNumber(part);
          if (m > 0) month = m;
        }
      }

      // إذا لم نجد السنة، نستخدم السنة الحالية
      year ??= DateTime.now().year;
      // إذا لم نجد الشهر، نستخدم الحالي
      month ??= DateTime.now().month;
      // إذا لم نجد اليوم، نستخدم 1
      day ??= 1;

      // إذا اكتملت الأركان، نرجع التاريخ
      return DateTime(year, month, day).toIso8601String();

    } catch (e) {
      print('فشل تحليل التاريخ: $rawValue -> $e');
      return DateTime.now().toIso8601String();
    }
  }

  // --- الدالة الرئيسية (لم تتغير كثيراً، فقط تستدعي _parseDate الجديدة) ---
  Future<void> importExcel(BuildContext context, WidgetRef ref, int personId, String currency) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
        int addedCount = 0;

        for (var table in decoder.tables.keys) {
          var rows = decoder.tables[table]!.rows;
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length < 4) continue;

            // استخدام الدالة الذكية
            String dateRaw = _parseDate(row[0]);

            String note = row[1]?.toString() ?? 'بدون وصف';

            // تنظيف الأرقام أيضاً من الأرقام العربية إذا وجدت
            String incomeStr = _normalizeArabicNumbers(row[2]?.toString() ?? '');
            String expenseStr = _normalizeArabicNumbers(row[3]?.toString() ?? '');

            double income = double.tryParse(incomeStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            double expense = double.tryParse(expenseStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

            String type = 'مصروف';
            double amount = 0.0;

            if (income > 0) { type = 'إيراد'; amount = income; }
            else if (expense > 0) { type = 'مصروف'; amount = expense; }
            else { continue; }

            Transaction transaction = Transaction(
              personId: personId,
              type: type,
              amount: amount,
              description: note,
              date: dateRaw,
              currency: currency,
            );

            await ref.read(databaseHelperProvider).addTransaction(transaction);
            addedCount++;
          }
        }

        ref.invalidate(transactionsProvider(personId));
        ref.invalidate(balanceProvider(BalanceParams(personId: personId, currency: 'SAR')));
        ref.invalidate(balanceProvider(BalanceParams(personId: personId, currency: 'YER')));
        ref.invalidate(personsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم استيراد $addedCount معاملة بنجاح ✅'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (context.mounted) {
        print('$e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }
}