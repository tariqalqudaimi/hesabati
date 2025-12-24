import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. إعداد الحركة
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // مدة الحركة
    );

    // نجعل الشعار يبدأ من حجم 0.8 وليس 0 لكي لا يختفي فجأة، بل يكمل حركة الشعار الأصلي
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );

    // 2. البدء
    _controller.forward();
    _navigateToNext();

    // 3. الخدعة السحرية: إزالة الشاشة الأصلية بعد رسم أول فريم
    // هذا يضمن أن المستخدم لن يرى شاشة سوداء أبداً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<void> _navigateToNext() async {
    // ننتظر انتهاء الأنيميشن + وقت إضافي بسيط
    await Future.delayed(const Duration(milliseconds: 2500));

    final isAuthenticated = await _checkBiometrics();

    if (mounted) {
      if (isAuthenticated) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      } else {
        // في حالة فشل البصمة، نعيد الطلب
        _navigateToNext();
      }
    }
  }

  Future<bool> _checkBiometrics() async {
    final isEnabled = await AuthService.isBiometricEnabled();
    if (!isEnabled) return true;
    return await AuthService.authenticate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // لون الخلفية مطابق تماماً للون flutter_native_splash في pubspec.yaml
      backgroundColor: const Color(0xFF2C3E50),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // تدرج لوني يبدأ بنفس لون الخلفية الأصلية لتجنب الوميض
          gradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الشعار المتحرك
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                // استخدمنا الأيقونة بدلاً من الصورة لضمان الوضوح
                child: Image(image: const AssetImage('assets/logo.png'))
            )),

            const SizedBox(height: 30),

            // النص
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Column(
                children: [
                  Text(
                    "دفتر حساباتي",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "إدارة مالية ذكية",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}