import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessagingService {
  static const String _keyAutoSms = 'auto_sms_enabled';

  static Future<void> setAutoSmsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSms, enabled);
  }

  static Future<bool> isAutoSmsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSms) ?? false;
  }

  static Future<void> sendTransactionMessage({
    required BuildContext context,
    required String name,
    required String? phone,
    required String type,
    required double amount,
    required String currency,
    required String description,
  }) async {
    // 1. التحقق من التفعيل
    if (!await isAutoSmsEnabled()) {
      print("الرسائل التلقائية غير مفعلة من الإعدادات");
      return;
    }

    // 2. التحقق من وجود رقم
    if (phone == null || phone.isEmpty) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم هاتف لهذا الشخص لإرسال الرسالة')));
      return;
    }

    // 3. معالجة الرقم بذكاء (إزالة الصفر، إضافة المفتاح)
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), ''); // حذف أي رموز غير الأرقام

    // منطق ذكي لإضافة المفتاح الدولي إذا نسيه المستخدم
    if (cleanPhone.length == 9 && (cleanPhone.startsWith('7') || cleanPhone.startsWith('1'))) {
      cleanPhone = '967$cleanPhone'; // يمن
    } else if (cleanPhone.length == 10 && cleanPhone.startsWith('05')) {
      cleanPhone = '966${cleanPhone.substring(1)}'; // سعودية (حذف الصفر)
    } else if (cleanPhone.length == 9 && cleanPhone.startsWith('5')) {
      cleanPhone = '966$cleanPhone'; // سعودية جاهز
    }

    // 4. نص الرسالة
    String message = "*إشعار مالي* 📢\n"
        "مرحباً $name،\n"
        "تم قيد عملية *$type* في حسابكم.\n"
        "💰 المبلغ: $amount $currency\n"
        "📝 البيان: $description\n"
        "📅 التاريخ: ${DateTime.now().toString().split(' ')[0]}\n"
        "شكراً لتعاملكم.";

    // 5. إنشاء الرابط (واتساب الرسمي)
    // نستخدم whatsapp://send للأندرويد لضمان الفتح المباشر
    final Uri whatsappUrl = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}");

    try {
      // محاولة الفتح
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication); // مهم جداً: تطبيق خارجي
      } else {
        // محاولة بديلة (رابط ويب) إذا فشل الرابط المباشر
        final Uri webUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح واتساب، تأكد من تثبيته')));
        }
      }
    } catch (e) {
      print("Error launching WhatsApp: $e");
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
}