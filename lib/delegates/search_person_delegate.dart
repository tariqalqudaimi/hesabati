import 'package:flutter/material.dart';
import '../models/person_model.dart';
import '../screens/user_account_screen.dart'; // تأكد من المسار الصحيح

class PersonSearchDelegate extends SearchDelegate {
  final List<Person> persons;

  PersonSearchDelegate(this.persons);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final results = persons.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();

    if (results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final person = results[index];
        return ListTile(
          leading: CircleAvatar(child: Text(person.name[0])),
          title: Text(person.name),
          onTap: () {
            // الانتقال لصفحة الشخص عند الضغط
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserAccountScreen(person: person))
            );
          },
        );
      },
    );
  }
}