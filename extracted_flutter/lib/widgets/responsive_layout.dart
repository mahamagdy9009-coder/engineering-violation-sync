// ============================================================
// responsive_layout.dart
// مساعد لتصميم واجهات متجاوبة (ديسكتوب + تابليت + موبايل)
// ============================================================

import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.desktop,
    this.tablet,
    this.mobile,
  });

  /// الواجهة الكاملة للديسكتوب (> 1100px)
  final Widget desktop;

  /// واجهة التابليت (600–1100px) — اختياري، يستخدم desktop إذا لم يُحدَّد
  final Widget? tablet;

  /// واجهة الموبايل (< 600px) — اختياري، يستخدم tablet/desktop إذا لم يُحدَّد
  final Widget? mobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 && mobile != null) {
          return mobile!;
        }
        if (constraints.maxWidth < 1100 && tablet != null) {
          return tablet!;
        }
        return desktop;
      },
    );
  }

  // ─── مساعدات ستاتيك ─────────────────────────────────────────

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1100;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100;

  /// عرض مرن: يختار بين قيمتين حسب حجم الشاشة
  static double value(
    BuildContext context, {
    required double mobile,
    double? tablet,
    required double desktop,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return mobile;
    if (w < 1100) return tablet ?? desktop;
    return desktop;
  }

  /// padding متجاوب
  static EdgeInsets padding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
  }

  /// عدد أعمدة الـ grid حسب الشاشة
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }
}
