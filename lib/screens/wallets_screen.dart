import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hesabati/screens/wallet_history_screen.dart';
import '../models/wallet_model.dart';
import '../services/database_helper.dart';
import '../providers/database_providers.dart';
import 'wallet_transfer_screen.dart';

// --- Providers ---
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
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  double _exchangeRate = 0.0;
  String _searchQuery = "";

  @override
  void dispose() {
    _rateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- دالة الحذف ---
  void _confirmDelete(Wallet wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف الحساب؟"),
        content: Text("هل أنت متأكد من حذف '${wallet.name}'؟ سيتم فصل العمليات المرتبطة به ولكن لن تُحذف."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteWallet(wallet.id!);
              ref.invalidate(walletsProvider);
              ref.invalidate(totalWalletsBalanceProvider('SAR'));
              ref.invalidate(totalWalletsBalanceProvider('YER'));
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- دالة الإضافة والتعديل ---
// داخل _WalletsScreenState

  void _showAddOrEditWalletDialog({Wallet? wallet}) async {
    final isEditing = wallet != null;
    final nameController = TextEditingController(text: isEditing ? wallet.name : '');
    final balanceController = TextEditingController();
    String currency = isEditing ? wallet.currency : 'SAR';

    // متغيرات لحمل رسائل الخطأ
    String? nameError;
    String? balanceError;

    if (isEditing) {
      final currentBalance = await ref.read(walletBalanceProvider(wallet.id!).future);
      balanceController.text = currentBalance.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isEditing ? 'تعديل / تسوية' : 'إضافة حساب جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الخزنة',
                  errorText: nameError, // إظهار الخطأ هنا
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setDialogState(() => nameError = null), // إخفاء الخطأ عند الكتابة
              ),
              const SizedBox(height: 15),
              if (!isEditing)
                DropdownButtonFormField<String>(
                  value: currency,
                  items: ['SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => currency = v!),
                  decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 15),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isEditing ? 'الرصيد الفعلي الحالي' : 'الرصيد الافتتاحي',
                  errorText: balanceError, // إظهار الخطأ هنا
                  border: const OutlineInputBorder(),
                  suffixText: currency,
                ),
                onChanged: (v) => setDialogState(() => balanceError = null),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50), foregroundColor: Colors.white),
              onPressed: () async {
                // --- التحقق من المدخلات ---
                bool isValid = true;
                if (nameController.text.trim().isEmpty) {
                  setDialogState(() => nameError = "يرجى إدخال الاسم");
                  isValid = false;
                }
                if (balanceController.text.trim().isEmpty) {
                  setDialogState(() => balanceError = "يرجى إدخال المبلغ");
                  isValid = false;
                }

                if (!isValid) return; // توقف إذا وجد خطأ

                // --- تنفيذ الحفظ ---
                final db = DatabaseHelper();
                final double enteredBalance = double.tryParse(balanceController.text) ?? 0.0;

                if (isEditing) {
                  await db.updateWallet(Wallet(id: wallet.id, name: nameController.text, currency: wallet.currency, initialBalance: wallet.initialBalance));
                  final oldBal = await ref.read(walletBalanceProvider(wallet.id!).future);
                  if (enteredBalance != oldBal) {
                    await db.adjustWalletBalance(walletId: wallet.id!, oldBalance: oldBal, newBalance: enteredBalance, currency: wallet.currency);
                  }
                } else {
                  await db.addWallet(Wallet(name: nameController.text, currency: currency, initialBalance: enteredBalance));
                }

                ref.invalidate(walletsProvider);
                ref.invalidate(walletBalanceProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("الخزينة والبنوك", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletTransferScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // إحصائيات علوية
          _buildTopSummary(),

          // بحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "بحث عن حساب...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // قائمة الحسابات
          Expanded(
            child: walletsAsync.when(
              data: (wallets) {
                final filtered = wallets.where((w) => w.name.contains(_searchQuery)).toList();
                if (filtered.isEmpty) return const Center(child: Text("لا توجد حسابات مضافة"));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _EnhancedWalletCard(
                    wallet: filtered[i],
                    onEdit: () => _showAddOrEditWalletDialog(wallet: filtered[i]),
                    onDelete: () => _confirmDelete(filtered[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("خطأ: $e")),
            ),
          ),

          // قسم المطابقة السفلي
          _buildReconciliationSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2C3E50),
        onPressed: () => _showAddOrEditWalletDialog(),
        label: const Text("إضافة حساب", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTopSummary() {
    final sar = ref.watch(totalWalletsBalanceProvider('SAR')).value ?? 0;
    final yer = ref.watch(totalWalletsBalanceProvider('YER')).value ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          _summaryBox("إجمالي السعودي", sar, Colors.greenAccent),
          const SizedBox(width: 12),
          _summaryBox("إجمالي اليمني", yer, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            FittedBox(child: Text(amount.toStringAsFixed(0), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationSection() {
    // 1. جلب البيانات من الـ Providers
    final actualSar = ref.watch(totalWalletsBalanceProvider('SAR')).value ?? 0.0;
    final bookSar = ref.watch(totalBalanceProvider('SAR')).value ?? 0.0;
    final diffSar = actualSar - bookSar;

    final actualYer = ref.watch(totalWalletsBalanceProvider('YER')).value ?? 0.0;
    final bookYer = ref.watch(totalBalanceProvider('YER')).value ?? 0.0;
    final diffYer = actualYer - bookYer;

    // 2. حساب الصافي النهائي باليمني (تحويل فارق السعودي + فارق اليمني)
    final double totalNetInYer = (diffSar * _exchangeRate) + diffYer;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 100), // مساحة للـ FAB
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("تحليل المطابقة (الفعلي vs الدفتري)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
          const SizedBox(height: 15),

          // عرض الفوارق بالتفصيل
          Row(
            children: [
              _buildDiffItem("فارق السعودي", diffSar, "SAR"),
              const SizedBox(width: 10),
              _buildDiffItem("فارق اليمني", diffYer, "YER"),
            ],
          ),

          const Divider(height: 25),

          // منطقة حساب الناتج النهائي
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                // مدخل سعر الصرف
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 0),
                    decoration: const InputDecoration(
                      labelText: "سعر الصرف",
                      prefixIcon: Icon(Icons.calculate_outlined, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // عرض الصافي النهائي
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("إجمالي العجز / الزيادة (YER)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      FittedBox(
                        child: Text(
                          "${totalNetInYer > 0 ? '+' : ''}${totalNetInYer.toStringAsFixed(0)}",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: totalNetInYer == 0 ? Colors.grey : (totalNetInYer > 0 ? Colors.green : Colors.red)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// عنصر عرض الفارق الصغير
  Widget _buildDiffItem(String label, double value, String currency) {
    final isPositive = value > 0;
    final isNegative = value < 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              "${isPositive ? '+' : ''}${value.toStringAsFixed(0)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: value == 0 ? Colors.blueGrey : (isPositive ? Colors.green : Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _diffText(String label, double val) {
    return Text("$label: ${val.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, color: val >= 0 ? Colors.green : Colors.red));
  }
}

// --- بطاقة الحساب المحسنة ---
class _EnhancedWalletCard extends ConsumerWidget {
  final Wallet wallet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EnhancedWalletCard({required this.wallet, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider(wallet.id!));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF0F2F5),
              child: Icon(wallet.name.contains("بنك") ? Icons.account_balance : Icons.wallet, color: const Color(0xFF2C3E50)),
            ),
            title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(wallet.currency, style: const TextStyle(fontSize: 12)),
            trailing: balanceAsync.when(
              data: (bal) => Text(bal.toStringAsFixed(2), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: bal >= 0 ? Colors.teal : Colors.redAccent)),
              loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const Icon(Icons.error),
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          // داخل كلاس _EnhancedWalletCard

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // زر السجل الجديد
              TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WalletHistoryScreen(walletId: wallet.id!, walletName: wallet.name))
                    );
                  },
                  icon: const Icon(Icons.history, size: 18, color: Colors.blueGrey),
                  label: const Text("السجل", style: TextStyle(color: Colors.blueGrey))
              ),

              TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_note, size: 20), label: const Text("تعديل")),

              TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), label: const Text("حذف", style: TextStyle(color: Colors.red))),
            ],
          )
        ],
      ),
    );
  }
}