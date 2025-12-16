import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // استيراد Riverpod
import '../providers/theme_provider.dart'; // استيراد theme_provider
import '../services/export_service.dart';
import '../services/google_drive_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}
// حوله إلى ConsumerWidget
class _SettingsScreenState extends ConsumerState<SettingsScreen> {


  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isLoading = false;

  Future<void> _handleDriveAction(Future<void> Function() action, String successMessage) async {
    setState(() => _isLoading = true);
    try {
      // التأكد من تسجيل الدخول أولاً
      var user = await _driveService.signIn();
      if (user == null) {
        throw Exception("فشل تسجيل الدخول أو تم الإلغاء");
      }

      await action();

      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Google Drive Error: $e"); // هذا السطر سيطبع الخطأ في الـ Terminal
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          // عرض الخطأ كاملاً في الشاشة
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- دالة النسخ الاحتياطي (مُحسّنة) - أصبحت static ---
  Future<void> _backupDatabase(BuildContext context) async {
    try {
      // استخدام الخدمة الجديدة التي تعتمد على المشاركة
      await ExportService().backupDatabase();
      // لا حاجة لرسالة تأكيد لأن نافذة المشاركة ستظهر
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل النسخ الاحتياطي: $e')),
      );
    }
  }


  // --- دالة الاستعادة (مُحسّنة) - أصبحت static ---
  static Future<void> _restoreDatabase(BuildContext context) async {
    if (await Permission.storage.request().isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          File backupFile = File(result.files.single.path!);
          var dbPath = await getDatabasesPath();
          String path = join(dbPath, 'hesabati.db');
          await backupFile.copy(path);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الاستعادة. الرجاء إعادة تشغيل التطبيق')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت الاستعادة: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صلاحية الوصول للملفات مطلوبة')));
    }
  }

  // دالة لمشاركة ملف قاعدة البيانات مباشرة
  Future<void> _shareBackup(BuildContext context) async {
    try {
      // 1. تحديد مسار قاعدة البيانات الحالية
      var dbPath = await getDatabasesPath();
      String path = join(dbPath, 'hesabati.db');
      File sourceFile = File(path);

      if (!await sourceFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للمشاركة')));
        return;
      }

      // 2. استخدام مكتبة Share Plus للمشاركة
      // هذه ستفتح نافذة تختار منها Drive أو Email
      await Share.shareXFiles(
          [XFile(sourceFile.path)],
          text: 'نسخة احتياطية لتطبيق دفتر الحسابات - ${DateTime.now()}'
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في المشاركة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // "شاهد" حالة الثيم الحالية لتحديد الخيار المختار
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          RadioListTile<ThemeMode>(
            title: const Text('فاتح'),
            value: ThemeMode.light,
            groupValue: currentTheme,
            onChanged: (value) {
              // "أخبر" الـ Provider بتغيير الحالة
              ref.read(themeModeProvider.notifier).state = value!;
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('داكن'),
            value: ThemeMode.dark,
            groupValue: currentTheme,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).state = value!;
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('وضع النظام'),
            value: ThemeMode.system,
            groupValue: currentTheme,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).state = value!;
            },
          ),
          const Divider(),
          const Text('البيانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('النسخ الاحتياطي للبيانات'),
            subtitle: const Text('حفظ نسخة من بياناتك في ملف على جهازك'),
            onTap: () => _backupDatabase(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Colors.blue),
            title: const Text('حفظ في Google Drive / إيميل'),
            subtitle: const Text('مشاركة ملف النسخة الاحتياطية للسحابة'),
            onTap: () async {
              // هنا نستخدم دالة جديدة للمشاركة
              await _shareBackup(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة البيانات'),
            subtitle: const Text('استعادة البيانات من ملف نسخة احتياطية'),
            onTap: () => _restoreDatabase(context),
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'مزامنة Google Drive (قيد التطوير)',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Google Drive Cloud", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),

          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),

          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Colors.green),
            title: const Text('رفع نسخة احتياطية لـ Google Drive'),
            subtitle: const Text('حفظ البيانات في السحابة'),
            onTap: _isLoading ? null : () => _handleDriveAction(
                _driveService.uploadBackup,
                'تم رفع النسخة الاحتياطية بنجاح إلى مجلد Hesabati_Backups'
            ),
          ),

          ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.orange),
            title: const Text('استعادة من Google Drive'),
            subtitle: const Text('سيتم استبدال البيانات الحالية'),
            onTap: _isLoading ? null : () => _handleDriveAction(
              _driveService.restoreBackup,
              'تم استعادة البيانات بنجاح! \n⚠️ الرجاء إغلاق التطبيق وفتحه لرؤية البيانات الجديدة.', // رسالة واضحة
            ),
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج من Google'),
            onTap: () async {
              await _driveService.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تسجيل الخروج')),
              );
            },
          ),

        ],
      ),
    );
  }
}
