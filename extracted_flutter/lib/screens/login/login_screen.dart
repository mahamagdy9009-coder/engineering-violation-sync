// ============================================================
// login_screen.dart — نسخة معدّلة مع دعم الموبايل والمزامنة
// التعديلات:
//   1. تخطيط متجاوب (ديسكتوب: Row، موبايل: Column)
//   2. فحص اعتماد الجهاز للموبايل (mobile/tablet)
//   3. تسجيل الجهاز وتشغيل المزامنة بعد الدخول
// ============================================================

import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../../sync/device_service.dart';
import '../../sync/sync_config.dart';
import '../../app_startup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController(text: 'bashkateb');
  final passwordController = TextEditingController(text: 'Fashn@2');

  bool loading = false;
  bool showPassword = false;
  // حالة فحص الجهاز (للموبايل فقط)
  String? _deviceCheckMessage;
  bool _deviceRejected = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('اكتب اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() {
      loading = true;
      _deviceCheckMessage = null;
      _deviceRejected = false;
    });

    try {
      // ── 1. التحقق من بيانات الدخول ──────────────────────────
      final user = await DatabaseService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (user == null) {
        _showError('اسم المستخدم أو كلمة المرور غير صحيحة');
        return;
      }

      // ── 2. فحص اعتماد الجهاز (للموبايل فقط) ─────────────────
      if (SyncConfig.isMobile && SyncConfig.syncEnabled) {
        setState(() =>
            _deviceCheckMessage = 'جاري التحقق من اعتماد الجهاز...');

        // تسجيل الجهاز أولاً (إن لم يكن مسجلاً)
        await DeviceService.registerDevice(username: username);

        final status =
            await DeviceService.checkStatus(forceRefresh: true);

        if (!mounted) return;

        switch (status) {
          case DeviceStatus.pending:
            setState(() {
              _deviceCheckMessage =
                  'تم إرسال طلب اعتماد الجهاز للمدير.\n'
                  'يرجى الانتظار حتى يتم الاعتماد للمزامنة.';
            });
            // نسمح بالدخول لكن بدون مزامنة
            break;

          case DeviceStatus.rejected:
            setState(() {
              _deviceRejected = true;
              _deviceCheckMessage =
                  'تم رفض هذا الجهاز من قِبَل المدير.\n'
                  'تواصل مع مشرفك للمزيد من المعلومات.';
            });
            return; // لا ندخل

          case DeviceStatus.serverUnreachable:
            // إذا السيرفر غير متاح: نكمل بدون مزامنة
            setState(() =>
                _deviceCheckMessage = null);
            break;

          default:
            setState(() =>
                _deviceCheckMessage = null);
        }
      }

      // ── 3. تشغيل المزامنة بعد الدخول ────────────────────────
      if (SyncConfig.syncEnabled) {
        AppStartup.onLogin(username).ignore();
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => DashboardScreen(user: user)),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('حدث خطأ أثناء تسجيل الدخول');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB42318),
        content: Text(message, textDirection: TextDirection.rtl),
      ),
    );
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
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF05352D),
                Color(0xFF0B6B55),
                Color(0xFFF5F2EA)
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // الموبايل: عرض أقل من 700
              if (constraints.maxWidth < 700) {
                return _buildMobileLayout();
              }
              return _buildDesktopLayout();
            },
          ),
        ),
      ),
    );
  }

  // ─── تخطيط الديسكتوب (Row) ──────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/images/logo.png', width: 140),
                const SizedBox(height: 28),
                const Text(
                  'الإدارة العامة لصرف بني سويف',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'هندسة صرف الفشن',
                  style: TextStyle(
                    color: Color(0xFFE5C07B),
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'برنامج متابعة وإدارة المخالفات الهندسية\nوالمحاضر الجنائية',
                  style: TextStyle(color: Colors.white70, fontSize: 17),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Center(child: _buildLoginCard()),
        ),
      ],
    );
  }

  // ─── تخطيط الموبايل (Column) ────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 90),
              const SizedBox(height: 16),
              const Text(
                'هندسة صرف الفشن',
                style: TextStyle(
                  color: Color(0xFFE5C07B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildLoginCard(isMobileLayout: true),
            ],
          ),
        ),
      ),
    );
  }

  // ─── بطاقة تسجيل الدخول ─────────────────────────────────────
  Widget _buildLoginCard({bool isMobileLayout = false}) {
    return Container(
      width: isMobileLayout ? double.infinity : 420,
      padding: EdgeInsets.all(isMobileLayout ? 24 : 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF05352D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // حقل اسم المستخدم
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: 'اسم المستخدم',
              prefixIcon:
                  const Icon(Icons.person_outline, color: Color(0xFF0B6B55)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF0B6B55), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // حقل كلمة المرور
          TextField(
            controller: passwordController,
            obscureText: !showPassword,
            onSubmitted: (_) => login(),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon:
                  const Icon(Icons.lock_outline, color: Color(0xFF0B6B55)),
              suffixIcon: IconButton(
                icon: Icon(
                    showPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey),
                onPressed: () =>
                    setState(() => showPassword = !showPassword),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF0B6B55), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // رسائل حالة الجهاز
          if (_deviceCheckMessage != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _deviceRejected
                    ? const Color(0xFFFDE8E8)
                    : const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _deviceRejected
                      ? const Color(0xFFB42318)
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _deviceRejected
                        ? Icons.cancel_outlined
                        : Icons.info_outline,
                    color: _deviceRejected
                        ? const Color(0xFFB42318)
                        : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _deviceCheckMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _deviceRejected
                            ? const Color(0xFFB42318)
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // زر الدخول
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (loading || _deviceRejected) ? null : login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B6B55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'دخول',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
