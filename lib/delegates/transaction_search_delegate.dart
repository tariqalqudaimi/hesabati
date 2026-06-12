import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../screens/user_account_screen.dart'; // ضروري لاستخدام ModernTransactionCard
import '../constants/app_colors.dart';

class TransactionSearchDelegate extends SearchDelegate {
  final List<Transaction> transactions;
  // التصحيح: تحديد نوع الدالة بدقة
  final Function(Transaction) onEdit;
  final Function(Transaction) onDelete;

  TransactionSearchDelegate({
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = transactions.where((t) {
      final descriptionMatch = t.description.toLowerCase().contains(query.toLowerCase());
      final amountMatch = t.amount.toString().contains(query);
      final dateMatch = t.date.contains(query);
      return descriptionMatch || amountMatch || dateMatch;
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final transaction = results[index];
        // استخدام البطاقة الحديثة
        return ModernTransactionCard(
          transaction: transaction,
          // التصحيح: نمرر دالة فارغة تستدعي الدالة الرئيسية مع المعاملة
          onEdit: () {
            close(context, null); // إغلاق البحث
            onEdit(transaction); // فتح التعديل
          },
          onDelete: () {
            close(context, null); // إغلاق البحث
            onDelete(transaction); // الحذف
          },
        );
      },
    );
  }
}