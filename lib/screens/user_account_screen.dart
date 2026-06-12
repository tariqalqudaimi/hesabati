import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../models/person_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart'; // مودل المحفظة
import '../providers/database_providers.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/messaging_service.dart'; // خدمة الرسائل
import 'wallets_screen.dart'; // للوصول لـ walletsProvider
import '../models/wallet_model.dart';
import '../services/messaging_service.dart';

class UserAccountScreen extends ConsumerStatefulWidget {
  final Person person;
  const UserAccountScreen({super.key, required this.person});

  @override
  ConsumerState<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends ConsumerState<UserAccountScreen> {
  String _selectedCurrency = 'SAR';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  void _refreshAllData() {
    ref.invalidate(transactionsProvider(widget.person.id!));
    ref.invalidate(balanceProvider(BalanceParams(personId: widget.person.id!, currency: 'SAR')));
    ref.invalidate(balanceProvider(BalanceParams(personId: widget.person.id!, currency: 'YER')));
    ref.invalidate(personsProvider);
    ref.invalidate(totalBalanceProvider('SAR'));
    ref.invalidate(totalBalanceProvider('YER'));
    ref.invalidate(walletsProvider);
    ref.invalidate(walletBalanceProvider);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2C3E50))),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
    }
  }

  void _clearDateFilter() {
    setState(() { _startDate = null; _endDate = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: const Color(0xFF2C3E50),
            title: _isSearching
                ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: Colors.white,
              decoration: const InputDecoration(hintText: 'ابحث...', hintStyle: TextStyle(color: Colors.white60), border: InputBorder.none),
              onChanged: (value) => setState(() => _searchQuery = value),
            )
                : Text(widget.person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Center(
                    child:
                        UserBalanceHeader(
                          personId: widget.person.id!, currency: _selectedCurrency,
                          startDate: _startDate, endDate: _endDate, searchQuery: _searchQuery,
                        ),

                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    if (_isSearching) { _isSearching = false; _searchQuery = ""; _searchController.clear(); }
                    else { _isSearching = true; }
                  });
                },
              ),
              if (!_isSearching)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) => _handleMenuSelection(value),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.upload_file, color: Colors.teal), SizedBox(width: 10), Text("استيراد Excel")])),
                    const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red), SizedBox(width: 10), Text("تصدير PDF")])),
                    const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.table_chart, color: Colors.green), SizedBox(width: 10), Text("تصدير Excel")])),
                  ],
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))]),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFE3E6EA), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(child: _buildCurrencyTab("السعودي (SAR)", "SAR")),
                        Expanded(child: _buildCurrencyTab("اليمني (YER)", "YER")),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Text("سجل المعاملات", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2C3E50))),
                      const Spacer(),
                      InkWell(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: _startDate != null ? const Color(0xFF2C3E50) : const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: _startDate != null ? Colors.white : Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(_startDate != null ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}' : "تصفية بالتاريخ", style: TextStyle(color: _startDate != null ? Colors.white : Colors.grey[800], fontSize: 12, fontWeight: FontWeight.bold)),
                              if (_startDate != null) ...[const SizedBox(width: 8), InkWell(onTap: _clearDateFilter, child: const Icon(Icons.close, size: 16, color: Colors.white))],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          TransactionsSliverList(
            key: ValueKey('$_selectedCurrency-$_startDate-$_searchQuery'),
            personId: widget.person.id!,
            currency: _selectedCurrency,
            startDate: _startDate,
            endDate: _endDate,
            searchQuery: _searchQuery,
            onDataChanged: _refreshAllData,
            onEdit: (t) => _showAddOrEditTransactionDialog(transaction: t),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditTransactionDialog(),
        backgroundColor: const Color(0xFF2C3E50),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('معاملة جديدة', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildCurrencyTab(String label, String currency) {
    bool isSelected = _selectedCurrency == currency;
    return GestureDetector(
      onTap: () => setState(() => _selectedCurrency = currency),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : []),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF2C3E50) : Colors.grey[700])),
      ),
    );
  }

  void _handleMenuSelection(String value) async {
    if (value == 'import') {
      ImportService().importExcel(context, ref, widget.person.id!, _selectedCurrency);
    } else {
      final transactions = await ref.read(transactionsProvider(widget.person.id!).future);
      if (transactions.isEmpty) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات'))); return; }
      String path = "";
      if (value == 'pdf') {
        path = await ExportService().exportToPdf(widget.person, transactions);
      } else {
        path = await ExportService().exportToExcel(widget.person, transactions);
      }
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ: $path'), backgroundColor: Colors.green));
    }
  }

  // --- نافذة الإضافة/التعديل (مع الخزنة والرسائل) ---
  // --- نافذة الإضافة/التعديل المطورة لدعم التوزيع على أكثر من خزنة ---
  void _showAddOrEditTransactionDialog({Transaction? transaction}) {
    final isEditing = transaction != null;
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: isEditing ? transaction.amount.toString() : '');
    final descriptionController = TextEditingController(text: isEditing ? transaction.description : '');
    String transactionType = isEditing ? transaction.type : 'مصروف';
    String currency = isEditing ? transaction.currency : _selectedCurrency;
    String? selectedImagePath = isEditing ? transaction.imagePath : null;
    DateTime selectedDate = isEditing ? DateTime.parse(transaction.date) : DateTime.now();

    // --- الجزء الجديد: قائمة التوزيع ---
    // إذا كان تعديل، نضع الخزنة الحالية كعنصر وحيد
    // إذا كان جديد، نبدأ بقائمة فارغة أو عنصر واحد
    List<Map<String, dynamic>> walletSplits = isEditing
        ? [{'walletId': transaction.walletId, 'amount': transaction.amount}]
        : [{'walletId': null, 'amount': 0.0}];

    bool isSplitPayment = false; // هل المستخدم يريد التوزيع؟

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {

              // حساب إجمالي المبالغ الموزعة للتأكد من مطابقتها للمبلغ الكلي
              double currentTotalDistributed() {
                return walletSplits.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                title: Text(isEditing ? 'تعديل معاملة' : 'إضافة معاملة'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                            controller: amountController,
                            decoration: const InputDecoration(labelText: 'إجمالي المبلغ', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              // إذا لم يكن توزيع، نحدث مبلغ الخزنة الأولى تلقائياً
                              if(!isSplitPayment) setStateDialog(() => walletSplits[0]['amount'] = double.tryParse(v) ?? 0.0);
                            },
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null
                        ),
                        const SizedBox(height: 10),
                        TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                        const SizedBox(height: 15),

                        // --- خيار التوزيع على أكثر من خزنة ---
                        if (!isEditing) ...[
                          Row(
                            children: [
                              Checkbox(
                                  value: isSplitPayment,
                                  onChanged: (v) => setStateDialog(() {
                                    isSplitPayment = v!;
                                    if(!isSplitPayment) {
                                      walletSplits = [{'walletId': null, 'amount': double.tryParse(amountController.text) ?? 0.0}];
                                    }
                                  })
                              ),
                              const Text("توزيع المبلغ على أكثر من خزنة", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                        ],

                        // --- قائمة الخزائن المختارة ---
                        FutureBuilder<List<Wallet>>(
                          future: ref.read(walletsProvider.future),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();
                            final validWallets = snapshot.data!.where((w) => w.currency == currency).toList();

                            return Column(
                              children: [
                                for (int i = 0; i < walletSplits.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<int>(
                                            value: walletSplits[i]['walletId'],
                                            decoration: InputDecoration(labelText: 'الخزنة ${i+1}', isDense: true, border: const OutlineInputBorder()),
                                            items: validWallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12)))).toList(),
                                            onChanged: (v) => setStateDialog(() => walletSplits[i]['walletId'] = v),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        if (isSplitPayment)
                                          Expanded(
                                            flex: 1,
                                            child: TextFormField(
                                              initialValue: walletSplits[i]['amount'].toString(),
                                              decoration: const InputDecoration(labelText: 'المبلغ', isDense: true, border: OutlineInputBorder()),
                                              keyboardType: TextInputType.number,
                                              onChanged: (v) => walletSplits[i]['amount'] = double.tryParse(v) ?? 0.0,
                                            ),
                                          ),
                                        if (isSplitPayment && walletSplits.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            onPressed: () => setStateDialog(() => walletSplits.removeAt(i)),
                                          )
                                      ],
                                    ),
                                  ),
                                if (isSplitPayment)
                                  TextButton.icon(
                                    onPressed: () => setStateDialog(() => walletSplits.add({'walletId': null, 'amount': 0.0})),
                                    icon: const Icon(Icons.add),
                                    label: const Text("إضافة خزنة أخرى"),
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 10),
                        // اختيار التاريخ والنوع والعملة (نفس كودك السابق)
                        // ... [بقيت حقول التاريخ والنوع والعملة] ...
                        Row(children: [
                          Expanded(child: DropdownButtonFormField<String>(initialValue: transactionType, decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()), items: ['مصروف', 'إيراد'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setStateDialog(() => transactionType = v!))),
                          const SizedBox(width: 10),
                          Expanded(child: DropdownButtonFormField<String>(initialValue: currency, decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()), items: ['SAR', 'YER'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setStateDialog(() { currency = v!; }))),
                        ]),
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (isSplitPayment)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "المتبقي: ${(double.tryParse(amountController.text) ?? 0) - currentTotalDistributed()}",
                        style: TextStyle(color: (double.tryParse(amountController.text) ?? 0) == currentTotalDistributed() ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
                  FilledButton(
                    onPressed: () async {
                      final totalAmount = double.tryParse(amountController.text) ?? 0.0;

                      // التحقق من صحة التوزيع
                      if (isSplitPayment && currentTotalDistributed() != totalAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("إجمالي مبالغ الخزائن يجب أن يساوي مبلغ المعاملة")));
                        return;
                      }

                      if (formKey.currentState!.validate()) {
                        final dbHelper = ref.read(databaseHelperProvider);

                        // --- الحفظ في قاعدة البيانات ---
                        // إذا كان تعديل: نحدث السجل الوحيد
                        if (isEditing) {
                          final newTx = Transaction(
                            id: transaction.id,
                            personId: widget.person.id!,
                            type: transactionType,
                            amount: totalAmount,
                            description: descriptionController.text,
                            date: selectedDate.toIso8601String(),
                            currency: currency,
                            imagePath: selectedImagePath,
                            walletId: walletSplits[0]['walletId'],
                          );
                          await dbHelper.updateTransaction(newTx);
                        }
                        // إذا كانت إضافة جديدة (قد تكون سجل واحد أو عدة سجلات)
                        else {
                          for (var split in walletSplits) {
                            if (split['amount'] > 0) {
                              final newTx = Transaction(
                                personId: widget.person.id!,
                                type: transactionType,
                                amount: split['amount'],
                                description: isSplitPayment
                                    ? "${descriptionController.text} (جزء من مبلغ)"
                                    : descriptionController.text,
                                date: selectedDate.toIso8601String(),
                                currency: currency,
                                imagePath: selectedImagePath,
                                walletId: split['walletId'],
                              );
                              await dbHelper.addTransaction(newTx);
                            }
                          }

                          // إرسال رسالة واتساب واحدة بالإجمالي
                          if (context.mounted) {
                            try {
                              await MessagingService.sendTransactionMessage(
                                context: context,
                                name: widget.person.name,
                                phone: widget.person.phone,
                                type: transactionType,
                                amount: totalAmount,
                                currency: currency,
                                description: descriptionController.text,
                              );
                            } catch (e) {}
                          }
                        }

                        _refreshAllData();
                        Navigator.of(ctx).pop();
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              );
            }
        );
      },
    );
  }
}

class UserBalanceHeader extends ConsumerWidget {
  final int personId;
  final String currency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;

  const UserBalanceHeader({super.key, required this.personId, required this.currency, this.startDate, this.endDate, this.searchQuery = ""});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider(personId));

    return transactionsAsync.when(
      data: (transactions) {
        var filtered = transactions.where((t) => t.currency == currency);
        if (startDate != null && endDate != null) {
          filtered = filtered.where((t) {
            final tDate = DateTime.parse(t.date);
            return tDate.isAfter(startDate!.subtract(const Duration(days: 1))) && tDate.isBefore(endDate!.add(const Duration(days: 1)));
          });
        }
        if (searchQuery.isNotEmpty) {
          filtered = filtered.where((t) => t.description.toLowerCase().contains(searchQuery.toLowerCase()) || t.amount.toString().contains(searchQuery));
        }

        double totalIncome = 0.0;
        double totalExpense = 0.0;
        for (var t in filtered) {
          if (t.type == 'إيراد') {
            totalIncome += t.amount;
          } else {
            totalExpense += t.amount;
          }
        }
        double netBalance = totalIncome - totalExpense;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min, // مهم جداً: تأخذ أقل مساحة ممكنة
            children: [
              const Text("الصافي", style: TextStyle(color: Colors.white70, fontSize: 12)),
              // FittedBox يحل مشكلة خروج الأرقام عن الشاشة
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  netBalance.toStringAsFixed(2),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: netBalance >= 0 ? const Color(0xFF4EE44E) : const Color(0xFFFF6B6B)),
                ),
              ),
              Text(currency, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Divider(color: Colors.white24, height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Expanded يحل مشكلة الـ Incorrect ParentData
                  Expanded(child: _buildStatItem("عليه (مدفوعات)", totalExpense, const Color(0xFFFF8A80))),
                  Container(width: 1, height: 30, color: Colors.white24),
                  Expanded(child: _buildStatItem("له (مقبوضات)", totalIncome, const Color(0xFF69F0AE))),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const CircularProgressIndicator(color: Colors.white),
      error: (_, __) => const Text("!", style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    return Column(
      children: [
        FittedBox(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))),
        const SizedBox(height: 4),
        FittedBox(child: Text(amount.toStringAsFixed(0), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
      ],
    );
  }
}

// --- قائمة المعاملات (تم تحديثها لدعم البحث المباشر) ---
class TransactionsSliverList extends ConsumerWidget {
  final int personId;
  final String currency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery; // متغير البحث
  final VoidCallback onDataChanged;
  final Function(Transaction) onEdit;

  const TransactionsSliverList({
    super.key,
    required this.personId,
    required this.currency,
    this.startDate,
    this.endDate,
    this.searchQuery = "", // قيمة افتراضية
    required this.onDataChanged,
    required this.onEdit
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider(personId));
    return transactionsAsync.when(
      data: (transactions) {
        // 1. فلترة العملة
        var filtered = transactions.where((t) => t.currency == currency);

        // 2. فلترة التاريخ
        if (startDate != null && endDate != null) {
          filtered = filtered.where((t) {
            final tDate = DateTime.parse(t.date);
            return tDate.isAfter(startDate!.subtract(const Duration(days: 1))) && tDate.isBefore(endDate!.add(const Duration(days: 1)));
          });
        }

        // 3. فلترة البحث (الجديد)
        if (searchQuery.isNotEmpty) {
          filtered = filtered.where((t) {
            final descMatch = t.description.toLowerCase().contains(searchQuery.toLowerCase());
            final amountMatch = t.amount.toString().contains(searchQuery);
            return descMatch || amountMatch;
          });
        }

        final list = filtered.toList();

        if (list.isEmpty) {
          return SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.receipt_long, size: 60, color: Colors.grey), const SizedBox(height: 10), Text("لا توجد معاملات", style: TextStyle(color: Colors.grey))])));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => ModernTransactionCard(
                transaction: list[index],
                onEdit: () => onEdit(list[index]),
                onDelete: () async {
                  await ref.read(databaseHelperProvider).deleteTransaction(list[index].id!);
                  onDataChanged();
                }
            ),
            childCount: list.length,
          ),
        );
      },
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SliverFillRemaining(child: Center(child: Text('خطأ'))),
    );
  }
}

// --- بطاقة المعاملة الحديثة ---
class ModernTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ModernTransactionCard({super.key, required this.transaction, required this.onEdit, required this.onDelete});

  void _shareWhatsApp() async {
    final text = "عملية: ${transaction.description}\nالمبلغ: ${transaction.amount} ${transaction.currency}\nالتاريخ: ${transaction.date.split('T')[0]}";
    final url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showImage(BuildContext context) {
    if (transaction.imagePath != null && File(transaction.imagePath!).existsSync()) showDialog(context: context, builder: (_) => Dialog(child: Image.file(File(transaction.imagePath!))));
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'إيراد';
    final color = isIncome ? AppColors.green : AppColors.red;
    final hasImage = transaction.imagePath != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 5, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: hasImage ? () => _showImage(context) : null,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: hasImage ? const Icon(Icons.camera_alt, color: Colors.blue, size: 20) : Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
          ),
        ),
        title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16,color: Colors.black)),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(DateTime.parse(transaction.date)), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(transaction.amount.toStringAsFixed(0), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            // IconButton(icon: const Icon(Icons.share, size: 20, color: Colors.green), onPressed: _shareWhatsApp),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                const PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}