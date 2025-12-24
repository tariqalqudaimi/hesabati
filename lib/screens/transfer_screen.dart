import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/person_model.dart';
import '../providers/database_providers.dart';
import '../services/database_helper.dart';
import '../constants/app_colors.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  Person? _fromPerson;
  Person? _toPerson;
  String _currency = 'SAR';
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  Future<void> _submitTransfer() async {
    if (_formKey.currentState!.validate()) {
      try {
        await ref.read(databaseHelperProvider).transferMoney(
          fromPersonId: _fromPerson!.id!,
          fromPersonName: _fromPerson!.name,
          toPersonId: _toPerson!.id!,
          toPersonName: _toPerson!.name,
          amount: double.parse(_amountController.text),
          currency: _currency,
          description: _descController.text,
        );

        ref.invalidate(personsProvider);
        ref.invalidate(totalBalanceProvider('SAR'));
        ref.invalidate(totalBalanceProvider('YER'));
        ref.invalidate(transactionsProvider(_fromPerson!.id!));
        ref.invalidate(transactionsProvider(_toPerson!.id!));
        ref.invalidate(balanceProvider(BalanceParams(personId: _fromPerson!.id!, currency: _currency)));
        ref.invalidate(balanceProvider(BalanceParams(personId: _toPerson!.id!, currency: _currency)));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحويل بنجاح ✅'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personsAsync = ref.watch(personsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            title: const Text('تحويل مالي', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.buttonPurple]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: personsAsync.when(
              data: (persons) {
                if (persons.length < 2) return const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("يجب إضافة حسابين على الأقل للتحويل", style: TextStyle(color: Colors.grey))));

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // بطاقة اختيار الأطراف
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Column(
                            children: [
                              _buildDropdown("من الحساب (المرسل)", persons, _fromPerson, (v) => setState(() => _fromPerson = v), Icons.arrow_upward, Colors.red),
                              const SizedBox(height: 10),
                              const Icon(Icons.arrow_downward_rounded, color: Colors.grey),
                              const SizedBox(height: 10),
                              _buildDropdown("إلى الحساب (المستلم)", persons.where((p) => p != _fromPerson).toList(), _toPerson, (v) => setState(() => _toPerson = v), Icons.arrow_downward, Colors.green),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // بطاقة المبلغ والتفاصيل
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: _buildTextField(_amountController, "المبلغ", isNumber: true, icon: Icons.numbers)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    flex: 1,
                                    child: DropdownButtonFormField<String>(
                                      value: _currency,
                                      decoration: _inputDecoration("العملة", Icons.currency_exchange),
                                      items: ['SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                                      onChanged: (v) => setState(() => _currency = v!),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              _buildTextField(_descController, "ملاحظة (اختياري)", icon: Icons.note_alt_outlined),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // زر التأكيد
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            onPressed: _submitTransfer,
                            child: const Text("تأكيد التحويل", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, required IconData icon}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _inputDecoration(label, icon),
      validator: (v) => isNumber && (v == null || v.isEmpty) ? "مطلوب" : null,
    );
  }

  Widget _buildDropdown(String label, List<Person> items, Person? value, Function(Person?) onChanged, IconData icon, Color iconColor) {
    return DropdownButtonFormField<Person>(
      value: value,
      decoration: _inputDecoration(label, icon).copyWith(prefixIcon: Icon(icon, color: iconColor)),
      items: items.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? "مطلوب" : null,
    );
  }
}