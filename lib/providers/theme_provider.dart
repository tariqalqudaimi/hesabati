import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- تأكد 100% من هذا السطر

// Provider بسيط لإدارة حالة الثيم الحالية (فاتح، داكن، أو وضع النظام).
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});