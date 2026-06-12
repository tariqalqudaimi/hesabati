import 'package:flutter/material.dart';
import '../models/person_model.dart';
import '../screens/home_screen.dart'; // لاستخدام ModernPersonCard
import '../constants/app_colors.dart';

class PersonSearchDelegate extends SearchDelegate {
  final List<Person> persons;

  PersonSearchDelegate(this.persons);

  // تخصيص ثيم البحث ليطابق التطبيق
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary, // نفس لون الهيدر
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
      scaffoldBackgroundColor: AppColors.background, // لون الخلفية الهادئ
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = persons.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();

    if (results.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: Colors.grey), SizedBox(height: 10), Text('لا توجد نتائج', style: TextStyle(color: Colors.grey))]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        // نستخدم نفس البطاقة الحديثة الموجودة في الهوم
        return ModernPersonCard(person: results[index], showBalances: false,);
      },
    );
  }
}