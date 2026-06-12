import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class WalletHistoryScreen extends StatelessWidget {
  final int walletId;
  final String walletName;

  const WalletHistoryScreen({super.key, required this.walletId, required this.walletName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("سجل: $walletName"),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getWalletTransactionsWithNames(walletId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("لا توجد عمليات مسجلة لهذه الخزينة"));
          }

          final transactions = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: transactions.length,
            itemBuilder: (context, i) {
              final t = transactions[i];
              final isIncome = t['type'] == 'إيراد';
              final String personName = t['personName'] ?? "غير معروف";
              final String description = t['description'] ?? "بدون وصف";

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(
                      isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Row(
                    children: [
                      // اسم الشخص (الحساب المسند إليه)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          personName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // الوصف
                      Expanded(
                        child: Text(
                          description,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      t['date'].toString().split('T')[0], // عرض التاريخ فقط
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  trailing: Text(
                    "${isIncome ? '+' : '-'}${t['amount']}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}