import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_model.dart';
import '../services/database_helper.dart';
import '../providers/database_providers.dart';
import 'wallet_transfer_screen.dart';

// Providers
final walletsProvider = FutureProvider<List<Wallet>>((ref) async {
  return DatabaseHelper().getWallets();
});

final walletBalanceProvider = FutureProvider.family<double, int>((ref, walletId) async {
  return DatabaseHelper().getWalletBalance(walletId);
});

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  // للتحكم بسعر الصرف لحساب الفارق النهائي
  final TextEditingController _rateController = TextEditingController();
  double _exchangeRate = 0.0;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('الخزينة والبنوك'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: "نقل ومصارفة",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletTransferScreen()));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- 1. قائمة الخزائن ---
          Expanded(
            child: walletsAsync.when(
              data: (wallets) {
                if (wallets.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("لم تضف أي خزنة أو بنك", style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) => WalletCard(
                    wallet: wallets[index],
                    onEdit: () => _showAddOrEditWalletDialog(wallet: wallets[index]), // زر التعديل
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('خطأ: $e')),
            ),
          ),

          // --- 2. قسم المطابقة والناتج النهائي ---
          _buildReconciliationSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditWalletDialog(),
        label: const Text('إضافة خزنة'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- قسم المطابقة (الجديد) ---
  Widget _buildReconciliationSection() {
    // مراقبة القيم للسعودي واليمني
    final actualSar = ref.watch(totalWalletsBalanceProvider('SAR')).value ?? 0;
    final bookSar = ref.watch(totalBalanceProvider('SAR')).value ?? 0;
    final diffSar = actualSar - bookSar;

    final actualYer = ref.watch(totalWalletsBalanceProvider('YER')).value ?? 0;
    final bookYer = ref.watch(totalBalanceProvider('YER')).value ?? 0;
    final diffYer = actualYer - bookYer;

    // حساب الصافي النهائي باليمني
    // المعادلة: (فارق السعودي * الصرف) + فارق اليمني
    final double totalNetInYer = (diffSar * _exchangeRate) + diffYer;
    final Color netColor = totalNetInYer >= 0 ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("تقرير المطابقة (الفارق)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
          const Divider(),
          
          // صفوف الفارق لكل عملة
          _buildDiffRow('SAR', diffSar),
          _buildDiffRow('YER', diffYer),
          
          const SizedBox(height: 10),
          
          // --- حقل سعر الصرف والناتج النهائي ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                // إدخال سعر الصرف
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "سعر الصرف (SAR->YER)",
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      setState(() {
                        _exchangeRate = double.tryParse(v) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 15),
                // الناتج النهائي
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("الصافي النهائي (يمني)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      FittedBox(
                        child: Text(
                          totalNetInYer.toStringAsFixed(0),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: netColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 90), // مساحة للزر العائم
        ],
      ),
    );
  }

  Widget _buildDiffRow(String currency, double diff) {
    Color color = diff == 0 ? Colors.grey : (diff > 0 ? Colors.green : Colors.red);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("فارق $currency:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(diff.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // --- نافذة إضافة / تعديل الخزنة (الذكية) ---
  void _showAddOrEditWalletDialog({Wallet? wallet}) async {
    final isEditing = wallet != null;
    final nameController = TextEditingController(text: isEditing ? wallet.name : '');
    final balanceController = TextEditingController();
    String currency = isEditing ? wallet.currency : 'SAR';

    // إذا كان تعديل، نجلب الرصيد الحالي الفعلي من الـ Provider
    if (isEditing) {
      // نستخدم الـ Provider لجلب الرصيد الحالي المحسوب
      final currentBalance = await ref.read(walletBalanceProvider(wallet.id!).future);
      balanceController.text = currentBalance.toStringAsFixed(2); // نعرض الرصيد الحالي
    } else {
      balanceController.text = '0'; // إذا جديد، صفر
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isEditing ? 'تعديل الرصيد الحالي' : 'إضافة مصدر مال'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // اسم الخزنة
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),

            ),
            const SizedBox(height: 15),
            
            // الرصيد (هنا السحر: إذا عدلته سيقوم بعمل تسوية)
            TextField(
              controller: balanceController, 
              decoration: InputDecoration(
                labelText: isEditing ? 'الرصيد الفعلي الموجود الآن' : 'الرصيد الافتتاحي',
                border: const OutlineInputBorder(),
                suffixText: currency,
              filled: isEditing,
              ), 
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            
            if (isEditing)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "تنبيه: تعديل هذا الرقم سيضيف عملية 'تسوية' تلقائية لضبط الحساب.",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 10),
            
            // العملة (مقفلة عند التعديل)
            if (!isEditing)
              DropdownButtonFormField<String>(
                value: currency,
                items: ['SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => currency = v!,
                decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2C3E50)),
            onPressed: () async {
              if (nameController.text.isNotEmpty && balanceController.text.isNotEmpty) {
                final db = DatabaseHelper();
                
                if (isEditing) {
                  // 1. تحديث الاسم فقط
                  final updatedWallet = Wallet(
                    id: wallet.id,
                    name: nameController.text,
                    currency: wallet.currency,
                    initialBalance: wallet.initialBalance, // لا نغير الافتتاحي
                  );
                  await db.updateWallet(updatedWallet);

                  // 2. معالجة تعديل الرصيد (التسوية)
                  final newBalance = double.tryParse(balanceController.text) ?? 0.0;
                  // نجلب الرصيد القديم مرة أخرى للتأكد
                  final oldBalance = await ref.read(walletBalanceProvider(wallet.id!).future);
                  
                  if (newBalance != oldBalance) {
                    await db.adjustWalletBalance(
                      walletId: wallet.id!,
                      oldBalance: oldBalance,
                      newBalance: newBalance,
                      currency: wallet.currency,
                    );
                  }

                } else {
                  // إضافة خزنة جديدة
                  await db.addWallet(Wallet(
                    name: nameController.text,
                    currency: currency,
                    initialBalance: double.tryParse(balanceController.text) ?? 0.0,
                  ));
                }
                
                // تحديث الواجهات
                ref.invalidate(walletsProvider);
                ref.invalidate(walletBalanceProvider); 
                ref.invalidate(totalWalletsBalanceProvider('SAR'));
                ref.invalidate(totalWalletsBalanceProvider('YER'));
                
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ التعديلات',style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }
}

// --- بطاقة الخزنة (معدلة بزر التعديل) ---
class WalletCard extends ConsumerWidget {
  final Wallet wallet;
  final VoidCallback onEdit; // دالة التعديل

  const WalletCard({super.key, required this.wallet, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider(wallet.id!));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFE8F6F3), borderRadius: BorderRadius.circular(10)),
          child: Icon(
            wallet.name.contains('بنك') ? Icons.account_balance : Icons.account_balance_wallet,
            color: const Color(0xFF16A085),
          ),
        ),
        title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        subtitle: Text(wallet.currency, style: const TextStyle(color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            balanceAsync.when(
              data: (bal) => Text(
                bal.toStringAsFixed(2),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: bal >= 0 ? const Color(0xFF27AE60) : const Color(0xFFC0392B)),
              ),
              loading: () => const Text('...'),
              error: (_, __) => const Text('!'),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
