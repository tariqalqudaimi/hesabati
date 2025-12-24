import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_model.dart';
import '../services/database_helper.dart';

// Provider لجلب المحافظ
final walletsProvider = FutureProvider<List<Wallet>>((ref) async {
  return DatabaseHelper().getWallets();
});

// Provider لحساب رصيد محفظة معينة
final walletBalanceProvider = FutureProvider.family<double, int>((ref, walletId) async {
  return DatabaseHelper().getWalletBalance(walletId);
});

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الخزينة والبنوك')),
      body: walletsAsync.when(
        data: (wallets) {
          if (wallets.isEmpty) {
            return const Center(child: Text("لم تضف أي حساب بنكي أو خزينة كاش"));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wallets.length,
            itemBuilder: (context, index) => WalletCard(wallet: wallets[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWalletDialog(context, ref),
        label: const Text('إضافة حساب/خزنة'),
        icon: const Icon(Icons.account_balance),
      ),
    );
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: "0");
    String currency = 'SAR';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مصدر مال'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم (مثلاً: كاش يمني، بنك الراجحي)')),
            TextField(controller: balanceController, decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: currency,
              items: ['SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => currency = v!,
              decoration: const InputDecoration(labelText: 'العملة'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await DatabaseHelper().addWallet(Wallet(
                  name: nameController.text,
                  currency: currency,
                  initialBalance: double.parse(balanceController.text),
                ));
                ref.invalidate(walletsProvider);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class WalletCard extends ConsumerWidget {
  final Wallet wallet;
  const WalletCard({super.key, required this.wallet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider(wallet.id!));

    return Card(
      child: ListTile(
        leading: Icon(
          wallet.name.contains('بنك') ? Icons.account_balance : Icons.wallet,
          color: Colors.blue,
        ),
        title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(wallet.currency),
        trailing: balanceAsync.when(
          data: (bal) => Text(
            bal.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: bal >= 0 ? Colors.green : Colors.red,
            ),
          ),
          loading: () => const Text('...'),
          error: (_, __) => const Text('!'),
        ),
      ),
    );
  }
}