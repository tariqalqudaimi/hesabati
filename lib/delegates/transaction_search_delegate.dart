import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../screens/user_account_screen.dart'; // لاستدعاء TransactionTile

class TransactionSearchDelegate extends SearchDelegate {
  final List<Transaction> transactions;
  final Function(Transaction) onEdit;
  final Function(Transaction) onDelete;

  TransactionSearchDelegate({
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    // منطق البحث: نبحث في الوصف أو المبلغ
    final results = transactions.where((t) {
      final descriptionMatch = t.description.toLowerCase().contains(query.toLowerCase());
      final amountMatch = t.amount.toString().contains(query);
      return descriptionMatch || amountMatch;
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final transaction = results[index];
        // نعيد استخدام نفس تصميم العنصر الموجود في شاشة الحساب
        return TransactionTile(
          transaction: transaction,
          onEdit: () {
            close(context, null); // إغلاق البحث
            onEdit(transaction); // فتح التعديل
          },
          onDelete: () async {
            close(context, null); // إغلاق البحث
            onDelete(transaction); // تنفيذ الحذف
          },
        );
      },
    );
  }
}