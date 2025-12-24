import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart'; // ضروري للاستعادة
import 'package:sqflite/sqflite.dart'; // ضروري لمسار قاعدة البيانات
import 'package:path/path.dart' as p; // ضروري للتعامل مع المسارات
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/google_drive_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isLoading = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await AuthService.isBiometricEnabled();
    setState(() => _isBiometricEnabled = enabled);
  }

  // --- دالة النسخ المحلي ---
  Future<void> _localBackup() async {
    try {
      String path = await ExportService().backupDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم النسخ بنجاح في:\n$path'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- دالة الاستعادة المحلية (الجديدة) ---
  Future<void> _restoreLocalBackup() async {
    try {
      // 1. فتح نافذة اختيار الملفات
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File backupFile = File(result.files.single.path!);
        
        // 2. تحديد مسار قاعدة البيانات الحالية
        var dbPath = await getDatabasesPath();
        String path = p.join(dbPath, 'hesabati.db');
        
        // 3. استبدال الملف الحالي بالنسخة المختارة
        await backupFile.copy(path);

        if (mounted) {
          // 4. إظهار رسالة نجاح
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('تمت الاستعادة بنجاح'),
              content: const Text('يجب إعادة تشغيل التطبيق الآن لتطبيق البيانات المستعادة.'),
              actions: [
                FilledButton(
                  onPressed: () => exit(0), // إغلاق التطبيق (اختياري، أو يغلقه المستخدم يدوياً)
                  child: const Text('إغلاق التطبيق'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستعادة: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- دالة التعامل مع جوجل درايف ---
  Future<void> _handleDriveAction(Future<void> Function() action, String successMsg) async {
    setState(() => _isLoading = true);
    try {
      var user = await _driveService.signIn();
      if (user == null) throw Exception("يجب تسجيل الدخول");
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            backgroundColor: const Color(0xFF2C3E50),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(child: Icon(Icons.settings, size: 80, color: Colors.white24)),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              if (_isLoading) const LinearProgressIndicator(),
              
              _buildSectionTitle("المظهر والأمان"),
              _buildSettingsCard([
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: Colors.purple),
                  title: const Text('قفل التطبيق',style: TextStyle(color: AppColors.black87),),
                  subtitle: const Text('المصادقة عند الدخول',style: TextStyle(color: AppColors.black87),),
                  value: _isBiometricEnabled,
                  onChanged: (value) async {
                    await AuthService.setBiometricEnabled(value);
                    setState(() => _isBiometricEnabled = value);
                  },
                ),
              ]),

              _buildSectionTitle("النسخ الاحتياطي (محلي)"),
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.save_alt, color: Colors.blue),
                  title: const Text('عمل نسخة احتياطية',style: TextStyle(color: AppColors.black87),),
                  subtitle: const Text('حفظ ملف في مجلد التنزيلات',style: TextStyle(color: AppColors.black87),),
                  onTap: _localBackup,
                ),
                const Divider(), // فاصل
                // --- الزر الذي طلبته ---
                ListTile(
                  leading: const Icon(Icons.restore_page, color: Colors.deepOrange),
                  title: const Text('استعادة نسخة محلية',style: TextStyle(color: AppColors.black87),),
                  subtitle: const Text('اختيار ملف من الجهاز',style: TextStyle(color: AppColors.black87),),
                  onTap: _restoreLocalBackup, // استدعاء الدالة
                ),
              ]),

              _buildSectionTitle("السحابة (Google Drive)"),
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: Colors.green),
                  title: const Text('رفع نسخة احتياطية',style: TextStyle(color: AppColors.black87),),
                  onTap: _isLoading ? null : () => _handleDriveAction(_driveService.uploadBackup, 'تم الرفع بنجاح'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cloud_download, color: Colors.orange),
                  title: const Text('استعادة من السحابة',style: TextStyle(color: AppColors.black87),),
                  subtitle: const Text('سيستبدل البيانات الحالية',style: TextStyle(color: AppColors.black87),),
                  onTap: _isLoading ? null : () => _handleDriveAction(_driveService.restoreBackup, 'تمت الاستعادة. أعد تشغيل التطبيق.'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('تسجيل الخروج من Google'),
                  onTap: () async {
                    await _driveService.signOut();
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الخروج')));
                  },
                ),
              ]),
              const SizedBox(height: 50),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title, 
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}