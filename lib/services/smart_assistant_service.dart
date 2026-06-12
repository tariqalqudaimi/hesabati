import '../models/person_model.dart';
import '../models/wallet_model.dart';

class SmartParsedData {
  double? amount;
  String? currency;
  Person? person;
  Wallet? wallet;
  String type = 'مصروف';
  String description = "";
  bool get isValid => amount != null && person != null;
}

class SmartAssistantService {
  static SmartParsedData parse(String text, List<Person> persons, List<Wallet> wallets) {
    final data = SmartParsedData();
    final lowerText = text.toLowerCase();

    // 1. استخراج الأرقام (المبلغ)
    final amountRegex = RegExp(r'(\d+)');
    final amountMatch = amountRegex.firstMatch(lowerText);
    if (amountMatch != null) {
      data.amount = double.tryParse(amountMatch.group(0)!);
    }

    // 2. العملة
    if (lowerText.contains("سعودي") || lowerText.contains("sar")) data.currency = "SAR";
    if (lowerText.contains("يمني") || lowerText.contains("yer")) data.currency = "YER";

    // 3. النوع
    if (lowerText.contains("استلمت") || lowerText.contains("قبضت") || lowerText.contains("دخل") || lowerText.contains("إيراد")) {
      data.type = "إيراد";
    }

    // 4. مطابقة الاسم
    for (var p in persons) {
      if (lowerText.contains(p.name.toLowerCase())) {
        data.person = p;
        break;
      }
    }

    // 5. مطابقة الخزنة
    for (var w in wallets) {
      if (lowerText.contains(w.name.toLowerCase())) {
        data.wallet = w;
        break;
      }
    }

    data.description = text;
    return data;
  }
}