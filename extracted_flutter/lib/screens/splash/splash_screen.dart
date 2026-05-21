import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../login/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF05352D), Color(0xFF0B6B55), Color(0xFFF0E8D8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.06,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 680,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 44,
                        vertical: 42,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFE5C07B).withValues(alpha: 0.7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1.03)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 190,
                            ),
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            'الإدارة العامة لصرف بني سويف',
                            style: TextStyle(
                              color: Color(0xFFFFF7E8),
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'هندسة صرف الفشن',
                            style: TextStyle(
                              color: Color(0xFFE5C07B),
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Divider(color: Color(0xFFE5C07B)),
                          const SizedBox(height: 20),
                          const Text(
                            'برنامج إدارة المخالفات',
                            style: TextStyle(
                              color: Color(0xFFFFF7E8),
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const SizedBox(
                            width: 46,
                            height: 46,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFFE5C07B),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'جاري التحميل...',
                            style: TextStyle(
                              color: Color(0xFFFFF7E8),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
