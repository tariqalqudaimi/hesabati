import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hesabati/screens/transfer_screen.dart';
import '../models/person_model.dart';
import '../providers/database_providers.dart';
import '../services/database_helper.dart';
import 'settings_screen.dart';
import 'user_account_screen.dart';
import '../delegates/search_person_delegate.dart';

// --- الويدجت الرئيسي للشاشة الرئيسية ---
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsync = ref.watch(personsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحسابات'),
        actions: [
          // في AppBar actions أضف:
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              // جلب قائمة الأشخاص الحالية للبحث فيها
              final persons = await ref.read(personsProvider.future);
              showSearch(context: context, delegate: PersonSearchDelegate(persons));
            },
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows), // أيقونة التحويل
            tooltip: 'تحويل',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
            },
          ),

          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personsProvider);
          ref.invalidate(totalBalanceProvider('SAR'));
          ref.invalidate(totalBalanceProvider('YER'));
        },
        child: Column(
          children: [
            // --- بطاقة الإجمالي الكلي ---
            const TotalBalanceCard(),

            // --- قائمة الحسابات ---
            Expanded(
              child: personsAsync.when(
                data: (persons) {
                  if (persons.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('لا توجد حسابات', style: TextStyle(fontSize: 22, color: Colors.grey)),
                          Text('ابدأ بإضافة حساب جديد عبر الزر أدناه', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), // تعديل بسيط للمسافات
                    itemCount: persons.length,
                    itemBuilder: (context, index) => PersonCard(person: persons[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('حدث خطأ: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditPersonDialog(context, ref),
        label: const Text('حساب جديد'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddOrEditPersonDialog(BuildContext context, WidgetRef ref, {Person? person}) {
    // ... هذا الكود صحيح ولا يحتاج تعديل
    final isEditing = person != null;
    final nameController = TextEditingController(text: isEditing ? person.name : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل اسم الحساب' : 'إضافة حساب جديد'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final dbHelper = ref.read(databaseHelperProvider);
                if (isEditing) {
                  final updatedPerson = Person(id: person.id, name: nameController.text);
                  await dbHelper.updatePerson(updatedPerson);
                } else {
                  final newPerson = Person(name: nameController.text);
                  await dbHelper.addPerson(newPerson);
                }
                ref.invalidate(personsProvider);
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );
  }
}

// --- ويدجت بطاقة الإجمالي الكلي (مع التصحيح) ---
class TotalBalanceCard extends ConsumerWidget {
  const TotalBalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإجمالي الكلي لجميع الحسابات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const Divider(height: 16),
            // --- هذا هو التصحيح ---
            // نعالج كل حالة على حدة قبل بناء ويدجت العرض
            _buildTotalBalanceRow(context, ref, 'SAR'),
            const SizedBox(height: 8),
            _buildTotalBalanceRow(context, ref, 'YER'),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء صف الرصيد الإجمالي مع معالجة كل الحالات
  Widget _buildTotalBalanceRow(BuildContext context, WidgetRef ref, String currency) {
    final totalAsync = ref.watch(totalBalanceProvider(currency));
    return totalAsync.when(
      data: (total) {
        final color = total >= 0 ? Colors.green.shade700 : Colors.red.shade700;
        return Row(
          children: [
            Text(currency, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            const Spacer(),
            Text(
              total.toStringAsFixed(2),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 22,
        child: Text('جاري الحساب...'),
      ),
      error: (_, __) => Text(
        'خطأ في الحساب',
        style: TextStyle(color: Colors.red.shade300),
      ),
    );
  }
}

// --- بطاقة الشخص بتصميم احترافي وأنيق ---
class PersonCard extends ConsumerWidget {
  final Person person;
  const PersonCard({super.key, required this.person});

  // دالة الحذف
  void _deletePerson(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف النهائي'),
        content: Text(
          'هل أنت متأكد من حذف حساب "${person.name}"؟\n\nتحذير: سيتم حذف جميع المعاملات والسجلات المالية المرتبطة بهذا الشخص ولا يمكن التراجع عن هذه الخطوة.',
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                // 1. إغلاق النافذة المنبثقة أولاً
                Navigator.pop(ctx);

                // 2. تنفيذ الحذف في قاعدة البيانات
                await ref.read(databaseHelperProvider).deletePerson(person.id!);

                // 3. تحديث واجهة المستخدم (مهم جداً)
                ref.invalidate(personsProvider);
                // تحديث الإجمالي الكلي أيضاً
                ref.invalidate(totalBalanceProvider('SAR'));
                ref.invalidate(totalBalanceProvider('YER'));

                // 4. رسالة نجاح
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم حذف حساب ${person.name} بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
                  );
                }
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => UserAccountScreen(person: person)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(person.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(person.name, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  // --- زر القائمة المنبثقة للحذف والتعديل ---
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        // استدعاء دالة التعديل من الـ Parent Widget
                        final homeScreen = context.findAncestorWidgetOfExactType<HomeScreen>();
                        homeScreen?._showAddOrEditPersonDialog(context, ref, person: person);
                      }
                      if (value == 'delete') {
                        _deletePerson(context, ref); // استدعاء دالة الحذف
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('تعديل الاسم')]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('حذف الحساب')]),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 0.5),
              BalanceRowWidget(personId: person.id!, currency: 'SAR'),
              const SizedBox(height: 8),
              BalanceRowWidget(personId: person.id!, currency: 'YER'),
            ],
          ),
        ),
      ),
    );
  }
}
// --- ويدجت منفصل لعرض الرصيد (يبقى كما هو) ---
class BalanceRowWidget extends ConsumerWidget {
  final int personId;
  final String currency;
  const BalanceRowWidget({super.key, required this.personId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider(BalanceParams(personId: personId, currency: currency)));
    return balanceAsync.when(
      data: (balance) {
        final color = balance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
        return Row(
          children: [
            Text(currency, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 16)),
            const Spacer(),
            Text(
              balance.toStringAsFixed(2),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 22, child: Center(child: Text('جاري الحساب...'))),
      error: (_, __) => Text('خطأ', style: TextStyle(color: Colors.red.shade300)),
    );
  }
}