import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'export_service.dart';
import 'google_drive_service.dart'; // تأكد من استيراد هذا

class AutoBackupService {
  static const String _keyLastBackupDate = 'last_backup_date';

  Future<void> checkAndRunAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupString = prefs.getString(_keyLastBackupDate);
      final now = DateTime.now();
      final todayString = "${now.year}-${now.month}-${now.day}";

      // إذا تم النسخ اليوم، توقف
      if (lastBackupString == todayString) {
        print("AutoBackup: Already done today.");
        return;
      }

      print("AutoBackup: Starting...");

      // 1. النسخ المحلي (إذا توفرت الصلاحية)
      if (await Permission.manageExternalStorage.isGranted) {
        await ExportService().backupDatabase();
        print("AutoBackup: Local backup success.");
      }

      // 2. النسخ السحابي (Google Drive) - صامت
      // نحاول تسجيل الدخول بصمت، إذا نجح نرفع الملف
      final driveService = GoogleDriveService();
      final user = await driveService.signInSilently(); // دالة جديدة سنضيفها للخدمة

      if (user != null) {
        await driveService.uploadBackup();
        print("AutoBackup: Cloud backup success.");
      } else {
        print("AutoBackup: User not signed in to Drive, skipping cloud backup.");
      }

      // 3. تحديث التاريخ
      await prefs.setString(_keyLastBackupDate, todayString);

    } catch (e) {
      print("AutoBackup Failed: $e");
    }
  }
}