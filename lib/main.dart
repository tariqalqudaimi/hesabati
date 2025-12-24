import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hesabati/providers/theme_provider.dart'; // <-- استيراد Provider الثيم
import 'package:hesabati/screens/SplashScreen.dart';
import 'package:hesabati/screens/home_screen.dart';
import 'package:hesabati/services/auth_service.dart';
import 'services/auto_backup_service.dart';
void main() {

  // التأكد من تهيئة Flutter قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // ProviderScope هو الويدجت الذي يجعل كل الـ Providers متاحة في جميع أنحاء التطبيق
  runApp(const ProviderScope(child: MyApp()));


}
class MyApp extends ConsumerStatefulWidget { // حولناها لـ Stateful لتشغيل الكود مرة واحدة
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

// تحويل MyApp إلى ConsumerWidget للتمكن من استخدام ref.watch
class _MyAppState extends ConsumerState<MyApp> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();

    _checkAuth();
  AutoBackupService().checkAndRunAutoBackup();
  }
  Future<void> _checkAuth() async {
    // 1. هل الميزة مفعلة؟
    final isEnabled = await AuthService.isBiometricEnabled();

    if (!isEnabled) {
      // إذا غير مفعلة، اسمح بالدخول فوراً
      setState(() => _isAuthenticated = true);
      return;
    }

    // 2. إذا مفعلة، اطلب البصمة
    final result = await AuthService.authenticate();
    setState(() {
      _isAuthenticated = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch "تراقب" حالة themeModeProvider.
    // في كل مرة تتغير فيها الحالة (مثلاً من الإعدادات)،
    // سيتم إعادة بناء هذا الويدجت (MyApp) بالقيمة الجديدة.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'دفتر الحسابات',
      debugShowCheckedModeBanner: false,

      // --- تعريف الثيمات ---
      // 1. الثيم الفاتح (Light Theme)
      theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: Colors.blue, // يمكنك تغيير هذا اللون الأساسي
          useMaterial3: true,
          
          fontFamily: 'Cairo', // تطبيق الخط على كل التطبيق
          appBarTheme: const AppBarTheme(
            centerTitle: false, // ليتماشى مع تصميم Material
          )
      ),

      // 2. الثيم الداكن (Dark Theme)
      darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue, // استخدام نفس اللون لتوحيد الهوية
          useMaterial3: true,
          fontFamily: 'Cairo',
          appBarTheme: const AppBarTheme(
            centerTitle: false,
          )
      ),

      // 3. تحديد الثيم الذي سيتم استخدامه بناءً على حالة الـ Provider
      themeMode: themeMode,

      // --- دعم اللغة العربية والاتجاه من اليمين لليسار ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''), // العربية
      ],
      locale: const Locale('ar', ''),

      home:SplashScreen(),
    );
  }
}