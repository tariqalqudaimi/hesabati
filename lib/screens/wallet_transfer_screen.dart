import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_model.dart';
import '../services/database_helper.dart';
import 'wallets_screen.dart';

class WalletTransferScreen extends ConsumerStatefulWidget {
  const WalletTransferScreen({super.key});

  @override
  ConsumerState<WalletTransferScreen> createState() => _WalletTransferScreenState();
}

class _WalletTransferScreenState extends ConsumerState<WalletTransferScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _fromWalletId;
  Wallet? _fromWallet;
  int? _toWalletId;
  Wallet? _toWallet;

  final _sourceAmountController = TextEditingController();
  final _rateController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _descController = TextEditingController();

  String _calculationHint = "";

  bool get _isExchange => _fromWallet != null && _toWallet != null && _fromWallet!.currency != _toWallet!.currency;

  void _calculateTarget() {
    if (_sourceAmountController.text.isEmpty) {
      _targetAmountController.text = "";
      setState(() => _calculationHint = "");
      return;
    }

    double amount = double.tryParse(_sourceAmountController.text) ?? 0;

    if (_isExchange) {
      double rate = double.tryParse(_rateController.text) ?? 0;

      if (rate > 0) {
        double result = 0.0;
        String from = _fromWallet!.currency;
        String to = _toWallet!.currency;

        if (from == 'SAR' && to == 'YER') {
          result = amount * rate;
          setState(() => _calculationHint = "العملية: $amount × $rate");
        } else if (from == 'YER' && to == 'SAR') {
          result = amount / rate;
          setState(() => _calculationHint = "العملية: $amount ÷ $rate");
        } else {
          result = amount * rate;
          setState(() => _calculationHint = "العملية: $amount × $rate");
        }
        _targetAmountController.text = result.toStringAsFixed(2);
      }
    } else {
      _targetAmountController.text = amount.toString();
      setState(() => _calculationHint = "نفس العملة (نقل مباشر)");
    }
  }

  Future<void> _submitTransfer() async {
    if (_formKey.currentState!.validate()) {
      try {
        double srcAmount = double.parse(_sourceAmountController.text);
        double trgAmount = _isExchange ? double.parse(_targetAmountController.text) : srcAmount;
        double rate = _isExchange ? double.parse(_rateController.text) : 1.0;

        await DatabaseHelper().transferBetweenWallets(
          fromWalletId: _fromWalletId!,
          fromWalletName: _fromWallet!.name,
          toWalletId: _toWalletId!,
          toWalletName: _toWallet!.name,
          sourceAmount: srcAmount,
          sourceCurrency: _fromWallet!.currency,
          targetAmount: trgAmount,
          targetCurrency: _toWallet!.currency,
          exchangeRate: rate,
          description: _descController.text,
        );

        ref.invalidate(walletsProvider);
        ref.invalidate(walletBalanceProvider(_fromWalletId!));
        ref.invalidate(walletBalanceProvider(_toWalletId!));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت العملية بنجاح ✅'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('نقل ومصارفة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: walletsAsync.when(
        data: (wallets) {
          if (wallets.length < 2) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange.shade300),
                  const SizedBox(height: 20),
                  const Text("يجب إضافة خزنتين على الأقل للقيام بالنقل", style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildSectionHeader("من الحساب (خصم)", Icons.upload_rounded, Colors.redAccent),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        _buildDropdown(
                          label: "اختر الخزنة/البنك",
                          value: _fromWalletId,
                          items: wallets, // نعرض كل الخزائن هنا
                          onChanged: (v) {
                            setState(() {
                              _fromWalletId = v;
                              _fromWallet = wallets.firstWhere((w) => w.id == v);

                              // --- التصحيح هنا: منع التضارب ---
                              // إذا اختار المستخدم في "المصدر" نفس الخزنة المختارة في "المستلم"
                              // نقوم بتصفير المستلم فوراً
                              if (_fromWalletId == _toWalletId) {
                                _toWalletId = null;
                                _toWallet = null;
                              }

                              _calculateTarget();
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        _buildAmountField(
                          controller: _sourceAmountController,
                          label: "المبلغ المرسل",
                          currency: _fromWallet?.currency,
                          color: Colors.redAccent,
                          onChanged: (_) => _calculateTarget(),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _isExchange
                        ? _buildExchangeRateCard()
                        : const Icon(Icons.arrow_downward_rounded, size: 30, color: Colors.grey),
                  ),

                  _buildSectionHeader("إلى الحساب (إيداع)", Icons.download_rounded, Colors.green),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        _buildDropdown(
                          label: "اختر الخزنة/البنك",
                          value: _toWalletId,
                          // الفلترة: لا تعرض الخزنة المختارة في المصدر
                          items: wallets.where((w) => w.id != _fromWalletId).toList(),
                          onChanged: (v) {
                            setState(() {
                              _toWalletId = v;
                              _toWallet = wallets.firstWhere((w) => w.id == v);
                              _calculateTarget();
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("المبلغ المستلم:", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                              Text(
                                "${_targetAmountController.text} ${_toWallet?.currency ?? ""}",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'ملاحظة / بيان',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _submitTransfer,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 10),
                          Text("تأكيد العملية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 10, right: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildExchangeRateCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF39C12), Color(0xFFF1C40F)]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.currency_exchange, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("سعر الصرف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: _rateController,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "أدخل السعر",
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              onChanged: (_) => _calculateTarget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField({required TextEditingController controller, required String label, String? currency, required Color color, required Function(String) onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        suffixText: currency,
        suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: color),
        prefixIcon: Icon(Icons.attach_money, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (v) => v!.isEmpty ? "مطلوب" : null,
    );
  }

  Widget _buildDropdown({required String label, required int? value, required List<Wallet> items, required Function(int?) onChanged}) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      ),
      items: items.map((w) => DropdownMenuItem(value: w.id, child: Text("${w.name} (${w.currency})", style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'مطلوب' : null,
    );
  }
}