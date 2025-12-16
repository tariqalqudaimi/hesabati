
import 'dart:ui';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../delegates/transaction_search_delegate.dart';
import '../models/person_model.dart';
import '../models/transaction_model.dart';
import '../providers/database_providers.dart';
import '../services/database_helper.dart';
import 'home_screen.dart'; // لاستيراد الويدجتس الزجاجية
import '../services/import_service.dart';
import '../services/export_service.dart';
// --- الويدجت الرئيسي للشاشة ---
class UserAccountScreen extends ConsumerStatefulWidget {
  final Person person;
  const UserAccountScreen({super.key, required this.person});

  @override
  ConsumerState<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends ConsumerState<UserAccountScreen> {
  // حالة محلية لتتبع العملة المختارة
  String _selectedCurrency = 'SAR';

  // دالة لتحديث كل البيانات عبر Riverpod بعد أي تغيير
  void _refreshAllData() {
    ref.invalidate(transactionsProvider(widget.person.id!));
    ref.invalidate(balanceProvider(BalanceParams(personId: widget.person.id!, currency: 'SAR')));
    ref.invalidate(balanceProvider(BalanceParams(personId: widget.person.id!, currency: 'YER')));
    ref.invalidate(personsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'استيراد من Excel',
            onPressed: () {
              // استدعاء خدمة الاستيراد
              ImportService().importExcel(context, ref, widget.person.id!, _selectedCurrency);
            },
          ),
          // --- زر التصدير الجديد ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: 'تصدير كشف حساب',
            // ... داخل PopupMenuButton -> onSelected
            onSelected: (value) async {
              final transactions = await ref.read(transactionsProvider(widget.person.id!).future);
              if (transactions.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد معاملات')));
                return;
              }

              try {
                String path = "";
                if (value == 'pdf') {
                  path = await ExportService().exportToPdf(widget.person, transactions);
                } else if (value == 'excel') {
                  path = await ExportService().exportToExcel(widget.person, transactions);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم الحفظ في التنزيلات:\n$path'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red), SizedBox(width: 8), Text('ملف PDF')]),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(children: [Icon(Icons.table_chart, color: Colors.green), SizedBox(width: 8), Text('ملف Excel')]),
              ),
            ],
          ),

          // ... داخل actions في AppBar
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث في المعاملات',
            onPressed: () async {
              // 1. جلب قائمة المعاملات الحالية
              final transactions = await ref.read(transactionsProvider(widget.person.id!).future);

              if (transactions.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد معاملات للبحث')));
                return;
              }

              // 2. فتح نافذة البحث
              showSearch(
                context: context,
                delegate: TransactionSearchDelegate(
                    transactions: transactions,
                    // تمرير دوال التعديل والحذف ليعملوا من داخل البحث أيضاً
                    onEdit: (t) => _showAddOrEditTransactionDialog(transaction: t),
                    onDelete: (t) async {
                      await ref.read(databaseHelperProvider).deleteTransaction(t.id!);
                      _refreshAllData();
                    }
                ),
              );
            },
          ),
// ... باقي الأزرار
        ],
      ),
      body: Column(
        children: [
          // --- 1. هيدر الحساب الذي يعرض الأرصدة وأزرار التبديل ---
          AccountHeader(
            personId: widget.person.id!,
            selectedCurrency: _selectedCurrency,
            onCurrencySelected: (currency) {
              setState(() {
                _selectedCurrency = currency;
              });
            },
          ),

          // --- 2. عنوان قسم المعاملات ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'سجل المعاملات ($_selectedCurrency)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color
                  ),
                ),
              ],
            ),
          ),

          // --- 3. قائمة المعاملات التي تتغير بناءً على العملة المختارة ---
          Expanded(
            child: TransactionsList(
              key: ValueKey(_selectedCurrency), // مهم للتبديل السلس
              personId: widget.person.id!,
              currency: _selectedCurrency,
              onDataChanged: _refreshAllData,
              onEdit: (transaction) => _showAddOrEditTransactionDialog(transaction: transaction),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditTransactionDialog(),
        label: const Text('معاملة جديدة'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // --- دالة موحدة وكاملة لإضافة وتعديل المعاملات ---
  void _showAddOrEditTransactionDialog({Transaction? transaction}) {
    final isEditing = transaction != null;
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: isEditing ? transaction.amount.toString() : '');
    final descriptionController = TextEditingController(text: isEditing ? transaction.description : '');
    String transactionType = isEditing ? transaction.type : 'مصروف';
    String currency = isEditing ? transaction.currency : _selectedCurrency;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? 'تعديل معاملة' : 'إضافة معاملة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? 'مبلغ غير صحيح' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'الوصف مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: transactionType,
                              decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
                              items: ['مصروف', 'إيراد'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                              onChanged: (v) => setState(() => transactionType = v!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: currency,
                              decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                              items: ['SAR', 'YER'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                              onChanged: (v) => setState(() => currency = v!),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(child: const Text('إلغاء'), onPressed: () => Navigator.of(ctx).pop()),
            FilledButton(
              child: Text(isEditing ? 'حفظ التعديل' : 'إضافة'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final dbHelper = ref.read(databaseHelperProvider);
                  if (isEditing) {
                    final updatedTransaction = transaction.copyWith(
                      type: transactionType,
                      amount: double.parse(amountController.text),
                      description: descriptionController.text,
                      currency: currency,
                    );
                    await dbHelper.updateTransaction(updatedTransaction);
                  } else {
                    final newTransaction = Transaction(
                      personId: widget.person.id!,
                      type: transactionType,
                      amount: double.parse(amountController.text),
                      description: descriptionController.text,
                      date: DateTime.now().toIso8601String(),
                      currency: currency,
                    );
                    await dbHelper.addTransaction(newTransaction);
                  }

                  _refreshAllData();
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// --- ويدجت هيدر الحساب (منفصل ومنظم) ---
class AccountHeader extends ConsumerWidget {
  final int personId;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencySelected;

  const AccountHeader({
    super.key,
    required this.personId,
    required this.selectedCurrency,
    required this.onCurrencySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: BalanceCard(personId: personId, currency: 'SAR')),
              const SizedBox(width: 12),
              Expanded(child: BalanceCard(personId: personId, currency: 'YER')),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'SAR', label: Text('السعودي'), icon: Icon(Icons.attach_money)),
              ButtonSegment(value: 'YER', label: Text('اليمني'), icon: Icon(Icons.money)),
            ],
            selected: {selectedCurrency},
            onSelectionChanged: (newSelection) {
              onCurrencySelected(newSelection.first);
            },
          ),
        ],
      ),
    );
  }
}

// --- بطاقة عرض الرصيد ---
class BalanceCard extends ConsumerWidget {
  final int personId;
  final String currency;
  const BalanceCard({super.key, required this.personId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider(BalanceParams(personId: personId, currency: currency)));
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: balanceAsync.when(
          data: (balance) {
            final color = balance >= 0 ? Colors.green : Colors.red;
            return Column(
              children: [
                Text(
                  currency == 'SAR' ? 'الرصيد السعودي' : 'الرصيد اليمني',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  balance.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: SizedBox(height: 50, child: CircularProgressIndicator())),
          error: (_, __) => const Text('خطأ'),
        ),
      ),
    );
  }
}

// --- قائمة عرض المعاملات ---
class TransactionsList extends ConsumerWidget {
  final int personId;
  final String currency;
  final VoidCallback onDataChanged;
  final Function(Transaction) onEdit;

  const TransactionsList({super.key, required this.personId, required this.currency, required this.onDataChanged, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider(personId));

    return transactionsAsync.when(
      data: (transactions) {
        final filteredTransactions = transactions.where((t) => t.currency == currency).toList();

        if (filteredTransactions.isEmpty) {
          return Center(child: Text('لا توجد معاملات بعملة $currency'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction = filteredTransactions[index];
            return TransactionTile(
              transaction: transaction,
              onEdit: () => onEdit(transaction),
              onDelete: () async {
                await ref.read(databaseHelperProvider).deleteTransaction(transaction.id!);
                onDataChanged();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${transaction.description} تم الحذف')));
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('خطأ في تحميل المعاملات')),
    );
  }
}

// --- عنصر المعاملة في القائمة ---
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TransactionTile({super.key, required this.transaction, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'إيراد';
    final color = isIncome ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color),
        ),
        title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(DateTime.parse(transaction.date))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              transaction.amount.toStringAsFixed(2),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('تعديل')),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('حذف')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}