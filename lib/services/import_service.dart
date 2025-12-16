import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart'; // المكتبة الجديدة
import '../models/transaction_model.dart';
import '../providers/database_providers.dart';

class ImportService {

  // دالة تحويل الشهر (كما هي)
  int _getMonthNumber(String monthName) {
    const months = {
      'يناير': 1, 'فبراير': 2, 'مارس': 3, 'أبريل': 4, 'مايو': 5, 'يونيو': 6,
      'يوليو': 7, 'أغسطس': 8, 'سبتمبر': 9, 'أكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    String key = monthName.trim();
    for (var m in months.keys) {
      if (key.contains(m)) return months[m]!;
    }
    return 1;
  }

  // دالة تحويل التاريخ (كما هي)
  String _parseDate(String rawDate) {
    try {
      String datePart = rawDate.split(' ').first;
      List<String> parts = datePart.split('-');
      if (parts.length >= 3) {
        int day = int.parse(parts[0]);
        int month = _getMonthNumber(parts[1]);
        int year = int.parse(parts[2]);
        return DateTime(year, month, day).toIso8601String();
      }
    } catch (e) {
      print('تاريخ غير قياسي: $e');
    }
    return DateTime.now().toIso8601String();
  }

  // الدالة الرئيسية للاستيراد (معدلة للمكتبة الجديدة)
  Future<void> importExcel(BuildContext context, WidgetRef ref, int personId, String currency) async {
    try {
      // 1. السماح باختيار الصيغتين
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'], // الآن ندعم الاثنين
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();

        // 2. استخدام SpreadsheetDecoder الذي يدعم الصيغتين
        // update: true يسمح للمكتبة باكتشاف نوع الملف تلقائياً
        var decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);

        int addedCount = 0;

        // المرور على الجداول
        for (var table in decoder.tables.keys) {
          // ملاحظة: هذه المكتبة تعطينا البيانات جاهزة ولا نحتاج للتعامل مع rows[i].value
          // rows هنا هي List<List<dynamic>>
          var rows = decoder.tables[table]!.rows;

          // تخطي الصف الأول (العناوين)
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];

            // التأكد من أن الصف فيه بيانات
            if (row.length < 4) continue;

            // القراءة من الخلايا
            String dateRaw = row[0]?.toString() ?? '';
            String note = row[1]?.toString() ?? 'بدون وصف';
            String incomeStr = row[2]?.toString() ?? '';
            String expenseStr = row[3]?.toString() ?? '';

            // تنظيف الأرقام
            double income = double.tryParse(incomeStr.replaceAll(',', '')) ?? 0.0;
            double expense = double.tryParse(expenseStr.replaceAll(',', '')) ?? 0.0;

            String type = 'مصروف';
            double amount = 0.0;

            if (income > 0) {
              type = 'إيراد';
              amount = income;
            } else if (expense > 0) {
              type = 'مصروف';
              amount = expense;
            } else {
              continue;
            }

            Transaction transaction = Transaction(
              personId: personId,
              type: type,
              amount: amount,
              description: note,
              date: _parseDate(dateRaw),
              currency: currency,
            );

            await ref.read(databaseHelperProvider).addTransaction(transaction);
            addedCount++;
          }
        }

        // 3. تحديث الواجهة
        ref.invalidate(transactionsProvider(personId));
        ref.invalidate(balanceProvider(BalanceParams(personId: personId, currency: 'SAR')));
        ref.invalidate(balanceProvider(BalanceParams(personId: personId, currency: 'YER')));
        ref.invalidate(personsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم استيراد $addedCount معاملة بنجاح ✅')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: تأكد أن الملف ليس تالفاً ($e)')),
        );
      }
    }
  }
}