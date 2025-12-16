import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/person_model.dart';
import '../providers/database_providers.dart';
import '../services/database_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    final personsAsync = ref.watch(personsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل بين الحسابات')),
      body: personsAsync.when(
        data: (persons) {
          if (persons.length < 2) {
            return const Center(child: Text('تحتاج لشخصين على الأقل للقيام بتحويل'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // --- من حساب ---
                  DropdownButtonFormField<Person>(
                    decoration: const InputDecoration(labelText: 'من حساب (المُرسل)', border: OutlineInputBorder()),
                    value: _fromPerson,
                    items: persons.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (val) => setState(() => _fromPerson = val),
                    validator: (val) => val == null ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 20),

                  // --- أيقونة تحويل ---
                  const Icon(Icons.arrow_downward, size: 30, color: Colors.blue),
                  const SizedBox(height: 20),

                  // --- إلى حساب ---
                  DropdownButtonFormField<Person>(
                    decoration: const InputDecoration(labelText: 'إلى حساب (المستلم)', border: OutlineInputBorder()),
                    value: _toPerson,
                    items: persons.where((p) => p != _fromPerson).map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (val) => setState(() => _toPerson = val),
                    validator: (val) => val == null ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 20),

                  // --- المبلغ والعملة ---
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          items: ['SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setState(() => _currency = val!),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- ملاحظة ---
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 30),

                  // --- زر التنفيذ ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('إتمام التحويل', style: TextStyle(fontSize: 18)),
                      onPressed: _submitTransfer,
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

        // تحديث كل البيانات
        ref.invalidate(personsProvider);
        ref.invalidate(totalBalanceProvider('SAR'));
        ref.invalidate(totalBalanceProvider('YER'));
        ref.invalidate(transactionsProvider(_fromPerson!.id!));
        ref.invalidate(transactionsProvider(_toPerson!.id!));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحويل بنجاح ✅'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحويل: $e')));
      }
    }
  }
}