import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hesabati/screens/wallets_screen.dart';
import '../models/person_model.dart';
import '../providers/database_providers.dart';
import '../constants/app_colors.dart';

import '../widgets/currency_converter_dialog.dart';
import 'settings_screen.dart';
import 'user_account_screen.dart';
import '../delegates/search_person_delegate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _showBalance = false;
  bool _showAccountBalances = false;

  // متغيرات التحويل
  final _transferFormKey = GlobalKey<FormState>();
  Person? _fromPerson;
  Person? _toPerson;
  String _transferCurrency = 'SAR';
  final _transferAmountController = TextEditingController();
  final _transferDescController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnimation = CurvedAnimation(parent: _animationController, curve: Curves.fastOutSlowIn);
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transferAmountController.dispose();
    _transferDescController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _submitTransfer() async {
    if (_transferFormKey.currentState!.validate()) {
      try {
        await ref.read(databaseHelperProvider).transferMoney(
          fromPersonId: _fromPerson!.id!,
          fromPersonName: _fromPerson!.name,
          toPersonId: _toPerson!.id!,
          toPersonName: _toPerson!.name,
          amount: double.parse(_transferAmountController.text),
          currency: _transferCurrency,
          description: _transferDescController.text,
        );

        ref.invalidate(personsProvider);
        ref.invalidate(totalBalanceProvider('SAR'));
        ref.invalidate(totalBalanceProvider('YER'));
        ref.invalidate(transactionsProvider(_fromPerson!.id!));
        ref.invalidate(transactionsProvider(_toPerson!.id!));
        ref.invalidate(balanceProvider(BalanceParams(personId: _fromPerson!.id!, currency: _transferCurrency)));
        ref.invalidate(balanceProvider(BalanceParams(personId: _toPerson!.id!, currency: _transferCurrency)));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحويل بنجاح ✅'), backgroundColor: Colors.green));
          Navigator.pop(context); // إغلاق الديالوج
          // تنظيف الحقول
          _fromPerson = null;
          _toPerson = null;
          _transferAmountController.clear();
          _transferDescController.clear();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  void _showTransferDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final personsAsync = ref.watch(personsProvider);
          return personsAsync.when(
            data: (persons) {
              if (persons.length < 2) {
                return AlertDialog(
                  title: const Text('تحويل مالي'),
                  content: const Text("يجب إضافة حسابين على الأقل للتحويل"),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق'))],
                );
              }
              return SingleChildScrollView(
                child: Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.background, AppColors.lightGrey],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _transferFormKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'تحويل مالي',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary, shadows: const [Shadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]),
                            ),
                            const SizedBox(height: 20),
                            // بطاقة اختيار الأطراف
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.darkGrey,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
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
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.darkGrey,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 2, child: _buildTextField(_transferAmountController, "المبلغ", isNumber: true, icon: Icons.numbers)),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        flex: 1,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _transferCurrency,
                                          decoration: _inputDecoration("العملة", Icons.currency_exchange),
                                          items: ['SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                                          onChanged: (v) => setState(() => _transferCurrency = v!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  _buildTextField(_transferDescController, "ملاحظة (اختياري)", icon: Icons.note_alt_outlined),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            // الأزرار
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text('إغلاق', style: TextStyle(color: AppColors.grey700)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _submitTransfer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 5,
                                    ),
                                    child: const Text("تأكيد التحويل", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Dialog(child: Center(child: CircularProgressIndicator())),
            error: (e, s) => AlertDialog(title: const Text('خطأ'), content: Text('خطأ: $e'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق'))]),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.grey700),
      prefixIcon: Icon(icon, color: AppColors.grey700),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.greyShade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 2)),
      filled: true,
      fillColor: AppColors.white,
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
    return DropdownButtonFormField<Person>(dropdownColor: AppColors.lightGrey,

      initialValue: value,
      decoration: _inputDecoration(label, icon).copyWith(prefixIcon: Icon(icon, color: iconColor)),
      items: items.map((p) => DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(color: AppColors.black87)))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? "مطلوب" : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final personsAsync = ref.watch(personsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. الهيدر الفخم
              SliverAppBar(
                expandedHeight: 230.0,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('حساباتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  centerTitle: true,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(child: Center(child: TotalBalanceWidget(showBalance: _showBalance, onToggle: () => setState(() => _showBalance = !_showBalance)))),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),

              // 2. عنوان القائمة
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      const Text("الحسابات المسجلة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.black87)),
                      IconButton(
                        icon: Icon(_showAccountBalances ? Icons.visibility_off : Icons.visibility, color: AppColors.grey700, size: 20),
                        onPressed: () => setState(() => _showAccountBalances = !_showAccountBalances),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text("${personsAsync.valueOrNull?.length ?? 0}", style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. القائمة
              personsAsync.when(
                data: (persons) {
                  if (persons.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_off, size: 60, color: AppColors.grey), SizedBox(height: 10), Text("لا توجد حسابات", style: TextStyle(color: AppColors.grey700))])),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => ModernPersonCard(person: persons[index], showBalances: _showAccountBalances),
                      childCount: persons.length,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                error: (e, s) => SliverFillRemaining(child: Center(child: Text("خطأ: $e"))),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // طبقة التعتيم
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: Colors.black.withOpacity(0.4), width: double.infinity, height: double.infinity),
            ),
        ],
      ),

      // القائمة العائمة
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildFabOption(Icons.person_add, "حساب جديد", AppColors.buttonBlue, () => _showAddOrEditPersonDialog(context, ref)),
          _buildFabOption(Icons.account_balance, "الخزنة والبنوك", const Color(0xFF009688), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen()))),
          _buildFabOption(Icons.compare_arrows, "تحويل مالي", AppColors.buttonPurple, () => _showTransferDialog()),
          _buildFabOption(Icons.monetization_on, "مصارفة عمل", AppColors.buttonBlue, () => showDialog(context: context, builder: (_) => const CurrencyConverterDialog())),
          _buildFabOption(Icons.search, "بحث", AppColors.buttonOrange, () async {
            final persons = await ref.read(personsProvider.future);
            if(mounted) showSearch(context: context, delegate: PersonSearchDelegate(persons));
          }),

          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'main_fab',
            onPressed: _toggleMenu,
            backgroundColor: AppColors.primary,
            child: RotationTransition(turns: _rotateAnimation, child: Icon(_isMenuOpen ? Icons.close : Icons.grid_view_rounded, size: 28, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFabOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,color: Colors.black)),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: label,
              onPressed: () { _toggleMenu(); onTap(); },
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // --- نافذة إضافة/تعديل المستخدم (تصميم جديد) ---
  void _showAddOrEditPersonDialog(BuildContext context, WidgetRef ref, {Person? person}) {
    final isEditing = person != null;
    final nameController = TextEditingController(text: isEditing ? person.name : '');
    final phoneController = TextEditingController(text: isEditing ? person.phone : '');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? 'تعديل الحساب' : 'إضافة حساب جديد', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الشخص',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              // --- حقل رقم الهاتف الجديد ---
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف (مع المفتاح)',
                  hintText: 'مثال: 967770000000',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        final db = ref.read(databaseHelperProvider);
                        if (isEditing) {
                          await db.updatePerson(Person(id: person.id, name: nameController.text, phone: phoneController.text));
                        } else {
                          await db.addPerson(Person(name: nameController.text, phone: phoneController.text));

                        }
                        ref.invalidate(personsProvider);
                        ref.invalidate(totalBalanceProvider('SAR'));
                        ref.invalidate(totalBalanceProvider('YER'));
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- ويدجت الإجمالي (Modern) ---
class TotalBalanceWidget extends ConsumerWidget {
  final bool showBalance;
  final VoidCallback onToggle;
  const TotalBalanceWidget({super.key, required this.showBalance, required this.onToggle});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSar = ref.watch(totalBalanceProvider('SAR'));
    final totalYer = ref.watch(totalBalanceProvider('YER'));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("إجمالي الرصيد العام", style: TextStyle(color: AppColors.white70, fontSize: 14)),
            IconButton(
              icon: Icon(showBalance ? Icons.visibility_off : Icons.visibility, color: AppColors.white70, size: 20),
              onPressed: onToggle,
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTotalItem(totalSar, "SAR", Icons.attach_money, showBalance),
            Container(height: 40, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 25)),
            _buildTotalItem(totalYer, "YER", Icons.money, showBalance),
          ],
        ),
      ],
    );
  }
  Widget _buildTotalItem(AsyncValue<double> val, String currency, IconData icon, bool showBalance) {
    return val.when(
      data: (v) => Column(children: [Text(showBalance ? v.toStringAsFixed(0) : "****", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.white)), Row(children: [Icon(icon, size: 12, color: AppColors.white70), Text(currency, style: const TextStyle(fontSize: 12, color: AppColors.white70))])]),
      loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2)),
      error: (_, __) => const Text("-", style: TextStyle(color: AppColors.white)),
    );
  }
}

// --- بطاقة الشخص (Modern) ---
class ModernPersonCard extends ConsumerWidget {
  final Person person;
  final bool showBalances;
  const ModernPersonCard({super.key, required this.person, required this.showBalances});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserAccountScreen(person: person))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
                      child: Text(person.name.substring(0, 1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(child: Text(person.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary))),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'edit') {
                          context.findAncestorStateOfType<_HomeScreenState>()?._showAddOrEditPersonDialog(context, ref, person: person);
                        } else {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('تعديل')), const PopupMenuItem(value: 'delete', child: Text('حذف'))],
                    )
                  ],
                ),
                const Divider(height: 25),
                Row(children: [
                  Expanded(child: _balanceItem(ref, 'SAR', showBalances)),
                  Expanded(child: _balanceItem(ref, 'YER', showBalances)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _balanceItem(WidgetRef ref, String currency, bool showBalances) {
    final bal = ref.watch(balanceProvider(BalanceParams(personId: person.id!, currency: currency)));
    return bal.when(
      data: (v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currency, style: TextStyle(fontSize: 10, color: AppColors.grey700)), Text(showBalances ? v.toStringAsFixed(0) : "****", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: showBalances ? (v >= 0 ? AppColors.green : AppColors.red) : AppColors.grey700))]),
      loading: () => const Text("..."), error: (_, __) => const Text("!"),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف الحساب'), content: Text('هل أنت متأكد من حذف ${person.name}؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red), onPressed: () async { Navigator.pop(ctx); await ref.read(databaseHelperProvider).deletePerson(person.id!); ref.invalidate(personsProvider); ref.invalidate(totalBalanceProvider('SAR')); ref.invalidate(totalBalanceProvider('YER')); }, child: const Text('حذف'))]));
  }
}