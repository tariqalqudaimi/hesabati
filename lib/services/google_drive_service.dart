import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class GoogleDriveService {
  final _googleSignIn = GoogleSignIn.standard(scopes: [drive.DriveApi.driveFileScope]);
  GoogleSignInAccount? _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      print("تم تسجيل الدخول: ${_currentUser?.email}");
      return _currentUser;
    } catch (e) {
      print('خطأ في تسجيل الدخول: $e');
      throw e;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<http.Client?> _getAuthClient() async {
    if (_currentUser == null) _currentUser = await _googleSignIn.signInSilently();
    if (_currentUser == null) return null;
    final authHeaders = await _currentUser!.authHeaders;
    return GoogleAuthClient(authHeaders);
  }

  // --- دالة الرفع (مع طباعة التفاصيل) ---
  Future<void> uploadBackup() async {
    print("بدء عملية الرفع...");
    final client = await _getAuthClient();
    if (client == null) throw Exception("يجب تسجيل الدخول أولاً");

    final driveApi = drive.DriveApi(client);
    var dbPath = await getDatabasesPath();
    String localPath = p.join(dbPath, 'hesabati.db');
    File localFile = File(localPath);

    if (!await localFile.exists()) throw Exception("ملف قاعدة البيانات غير موجود على الهاتف!");

    // البحث عن المجلد
    String? folderId = await _getOrCreateFolder(driveApi);
    print("تم تحديد المجلد: $folderId");

    // الرفع
    var media = drive.Media(localFile.openRead(), localFile.lengthSync());
    var driveFile = drive.File();
    driveFile.name = "hesabati_backup_${DateTime.now().millisecondsSinceEpoch}.db";
    driveFile.parents = [folderId!];

    var result = await driveApi.files.create(driveFile, uploadMedia: media);
    print("تم الرفع بنجاح. معرف الملف: ${result.id}");
  }

  // --- دالة الاستعادة (المحسّنة) ---
  Future<void> restoreBackup() async {
    print("بدء عملية الاستعادة...");
    final client = await _getAuthClient();
    if (client == null) throw Exception("يجب تسجيل الدخول أولاً");

    final driveApi = drive.DriveApi(client);
    String? folderId = await _getOrCreateFolder(driveApi);

    // البحث عن النسخ الاحتياطية
    var fileList = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: "createdTime desc",
      $fields: "files(id, name, size)", // طلبنا الحجم للتأكد
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      print("المجلد فارغ أو لا يمكن الوصول للملفات");
      throw Exception("لم يتم العثور على أي نسخ احتياطية في Google Drive");
    }

    print("تم العثور على ${fileList.files!.length} ملفات.");
    var latestFile = fileList.files!.first;
    print("جاري تحميل الملف الأحدث: ${latestFile.name} (ID: ${latestFile.id})");

    // تحميل الملف
    drive.Media fileMedia = await driveApi.files.get(latestFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    List<int> dataStore = [];
    await for (var data in fileMedia.stream) {
      dataStore.addAll(data);
    }

    print("تم تحميل البيانات. الحجم: ${dataStore.length} بايت");

    if (dataStore.isEmpty) throw Exception("الملف المحمل فارغ!");

    // كتابة الملف
    var dbPath = await getDatabasesPath();
    String localPath = p.join(dbPath, 'hesabati.db');
    File localFile = File(localPath);

    await localFile.writeAsBytes(dataStore, flush: true);
    print("تمت كتابة قاعدة البيانات بنجاح في: $localPath");
  }

  Future<String?> _getOrCreateFolder(drive.DriveApi driveApi) async {
    const folderName = "Hesabati_Backups";
    var response = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false",
    );

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first.id;
    }

    print("المجلد غير موجود، جاري إنشاؤه...");
    var folder = drive.File();
    folder.name = folderName;
    folder.mimeType = "application/vnd.google-apps.folder";
    var createResponse = await driveApi.files.create(folder);
    return createResponse.id;
  }
  // محاولة تسجيل الدخول بدون فتح نافذة (إذا كان مسجلاً سابقاً)
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (e) {
      return null;
    }
  }
}


class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}