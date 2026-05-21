// ============================================================
// dashboard_screen.dart — نسخة معدّلة
// التعديل:
//   • قائمة جانبية جديدة: الرئيسية (مع المحاضر الجنائية كقائمة فرعية)
//   • إضافة قسم "التقنين"
//   • لوحة التحكم الرئيسية: 8 بطاقات إحصائية
//   • الانتقال لصفحة المحاضر يحمل الإحصائيات معه
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../../services/data_normalization_service.dart';
import '../criminal_cases/criminal_cases_screen.dart';
import '../../gis/screens/gis_screen.dart';

import '../../notifications/approval_service.dart';
import '../../notifications/notification_service.dart';
import '../../notifications/notification_bell.dart';
import '../../notifications/approval_screen.dart';
import '../../notifications/my_requests_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../admin/device_approval_screen.dart';
import '../sync/sync_status_screen.dart';
import '../../database/session_service.dart';
import '../../widgets/sync_status_badge.dart';
import '../login/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> statsFuture;

  NotificationService? _notificationService;
  ApprovalService?     _approvalService;
  SessionService?      _sessionService;
  Timer?               _notifTimer;

  @override
  void initState() {
    super.initState();
    statsFuture = DatabaseService.getDashboardStats();
    _initServices();
  }

  Future<void> _initServices() async {
    final notifSvc    = await DatabaseService.getNotificationService();
    final approvalSvc = await DatabaseService.getApprovalService();
    final db          = await DatabaseService.database;
    final sessionSvc  = SessionService(db);

    final userId = widget.user['id'] as int? ?? 0;
    await notifSvc.load(userId);
    await sessionSvc.onLogin(userId);

    _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      notifSvc.refresh(userId);
    });

    if (mounted) {
      setState(() {
        _notificationService = notifSvc;
        _approvalService     = approvalSvc;
        _sessionService      = sessionSvc;
      });
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    final userId = widget.user['id'] as int? ?? 0;
    _sessionService?.onLogout(userId);
    super.dispose();
  }

  bool get _isManager {
    final role     = (widget.user['role']      ?? '').toString();
    final roleCode = (widget.user['role_code'] ?? '').toString();
    return role == 'manager' || roleCode == 'manager';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من النظام؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    _notifTimer?.cancel();
    final userId = widget.user['id'] as int? ?? 0;
    await _sessionService?.onLogout(userId);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openCriminalCases() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CriminalCasesScreen(currentUser: widget.user),
      ),
    ).then((_) {
      // تحديث الإحصائيات بعد العودة
      if (mounted) {
        setState(() {
          statsFuture = DatabaseService.getDashboardStats();
        });
      }
    });
  }

  Future<void> _runNormalization() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_fix_high, color: Color(0xFF05352D)),
              SizedBox(width: 10),
              Text('تطبيع البيانات ودمج المكرر'),
            ],
          ),
          content: const Text(
            'ستقوم هذه العملية بـ:\n\n'
            '• دمج المحاضر التي تشترك في نفس رقم المحضر والسنة\n'
            '• توحيد أسماء المصارف حسب القائمة الرسمية\n'
            '• توحيد أسماء المخالفين (الهمزات والمسافات)\n\n'
            'هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF05352D)),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('جارٍ تطبيع البيانات...'),
            ],
          ),
        ),
      ),
    );

    try {
      final db     = await DatabaseService.database;
      final result = await DataNormalizationService.applyAll(db);

      if (!mounted) return;
      Navigator.pop(context);

      setState(() { statsFuture = DatabaseService.getDashboardStats(); });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم بنجاح:\n'
            '• دُمج ${result['merged']} مجموعة من المحاضر المكررة\n'
            '• صُحِّح ${result['drain_fixed']} اسم مصرف\n'
            '• نُظِّم ${result['name_fixed']} اسم مخالف',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: const Color(0xFF0B6B55),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeName = (widget.user['employee_name'] ?? 'مستخدم').toString();
    final roleName     = (widget.user['role_name'] ?? 'موظف').toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EA),
        body: Column(
          children: [
            _Header(
              employeeName:        employeeName,
              roleName:            roleName,
              notificationService: _notificationService,
              currentUser:         widget.user,
              approvalService:     _approvalService,
              onLogout:            _logout,
            ),
            Expanded(
              child: Row(
                children: [
                  // ── القائمة الجانبية ──────────────────────────
                  _SideMenu(
                    currentUser:       widget.user,
                    approvalService:   _approvalService,
                    isManager:         _isManager,
                    onOpenCriminalCases: _openCriminalCases,
                    onOpenGis: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GisScreen()),
                    ),
                    onRunNormalization: _isManager ? _runNormalization : null,
                    onOpenAdminPanel: _isManager
                        ? () async {
                            final db = await DatabaseService.database;
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminPanelScreen(db: db),
                              ),
                            );
                          }
                        : null,
                    onOpenApproval: (_isManager && _approvalService != null)
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ApprovalScreen(
                                  approvalService: _approvalService!,
                                  currentUser: widget.user,
                                ),
                              ),
                            )
                        : null,
                    onOpenMyRequests: (!_isManager && _approvalService != null)
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MyRequestsScreen(
                                  approvalService: _approvalService!,
                                  currentUser: widget.user,
                                ),
                              ),
                            )
                        : null,
                    onOpenDeviceApproval: _isManager
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeviceApprovalScreen(
                                  currentUser: widget.user,
                                ),
                              ),
                            )
                        : null,
                    onOpenSyncStatus: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SyncStatusScreen(
                          currentUser: widget.user,
                        ),
                      ),
                    ),
                  ),

                  // ── منطقة المحتوى الرئيسية ────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: statsFuture,
                        builder: (context, snapshot) {
                          final stats = snapshot.data ?? const {};
                          return _HomeContent(
                            stats:      stats,
                            isManager:  _isManager,
                            isLoading:  snapshot.connectionState == ConnectionState.waiting,
                            onOpenCriminalCases: _openCriminalCases,
                            onRunNormalization:  _isManager ? _runNormalization : null,
                            onRefresh: () => setState(() {
                              statsFuture = DatabaseService.getDashboardStats();
                            }),
                          );
                        },
                      ),
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

// ══════════════════════════════════════════════════════════════
// محتوى الصفحة الرئيسية
// ══════════════════════════════════════════════════════════════

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.stats,
    required this.isManager,
    required this.isLoading,
    required this.onOpenCriminalCases,
    this.onRunNormalization,
    required this.onRefresh,
  });

  final Map<String, dynamic> stats;
  final bool     isManager;
  final bool     isLoading;
  final VoidCallback onOpenCriminalCases;
  final VoidCallback? onRunNormalization;
  final VoidCallback onRefresh;

  String _val(String key) =>
      isLoading ? '...' : (stats[key]?.toString() ?? '٠');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── شريط العنوان + زر التطبيع ──────────────────────────
        Row(
          children: [
            const Text(
              'الرئيسية',
              style: TextStyle(
                color: Color(0xFF05352D),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'تحديث الإحصائيات',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: Color(0xFF0B6B55)),
            ),
            if (isManager && onRunNormalization != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF05352D),
                  side: const BorderSide(color: Color(0xFF0B6B55)),
                ),
                onPressed: onRunNormalization,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('تطبيع البيانات ودمج المكرر'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ── شبكة البطاقات الإحصائية الثمان ────────────────────
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            // 1 — المصارف
            _StatCard(
              title: 'عدد المصارف',
              value: _val('total_drains'),
              icon: Icons.water_drop_outlined,
              color: const Color(0xFF0B6B55),
            ),
            // 2 — المحاضر الجنائية (قابل للنقر)
            _StatCard(
              title: 'المحاضر الجنائية',
              value: _val('total_cases'),
              icon: Icons.gavel,
              color: const Color(0xFF05352D),
              onTap: onOpenCriminalCases,
              tappable: true,
            ),
            // 3 — ملفات التقنين
            _StatCard(
              title: 'ملفات التقنين',
              value: _val('regularization_files'),
              icon: Icons.folder_special_outlined,
              color: const Color(0xFF6B3FA0),
            ),
            // 4 — التراخيص
            _StatCard(
              title: 'التراخيص',
              value: _val('license_files'),
              icon: Icons.badge_outlined,
              color: const Color(0xFF065F46),
            ),
            // 5 — الحجز الإداري
            _StatCard(
              title: 'الحجز الإداري',
              value: _val('admin_seizure_cases'),
              icon: Icons.account_balance_outlined,
              color: const Color(0xFF1D4ED8),
            ),
            // 6 — التبديد
            _StatCard(
              title: 'التبديد',
              value: _val('dissipation_cases'),
              icon: Icons.warning_amber_outlined,
              color: const Color(0xFFB45309),
            ),
            // 7 — الشكاوي
            _StatCard(
              title: 'الشكاوي',
              value: _val('complaints_cases'),
              icon: Icons.support_agent_outlined,
              color: const Color(0xFF0369A1),
            ),
            // 8 — طلبات / طلباتي
            _StatCard(
              title: isManager
                  ? 'طلبات بانتظار الاعتماد'
                  : 'طلباتي',
              value: _val('total_pending'),
              icon: isManager
                  ? Icons.pending_actions_outlined
                  : Icons.assignment_outlined,
              color: const Color(0xFFB42318),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── لوحة التحليلات ─────────────────────────────────────
        Expanded(
          child: _AnalyticsPanel(
            stats:    stats,
            isLoading: isLoading,
            onOpenCriminalCases: onOpenCriminalCases,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Header
// ══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.employeeName,
    required this.roleName,
    this.notificationService,
    required this.currentUser,
    this.approvalService,
    this.onLogout,
  });

  final String               employeeName;
  final String               roleName;
  final NotificationService? notificationService;
  final Map<String, dynamic> currentUser;
  final ApprovalService?     approvalService;
  final VoidCallback?        onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF05352D),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 54, height: 54),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'هندسة صرف الفشن - برنامج إدارة المخالفات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (notificationService != null)
            NotificationBell(
              notificationService: notificationService!,
              currentUser:         currentUser,
              approvalService:     approvalService,
            ),

          const SizedBox(width: 8),
          const SyncStatusBadge(),
          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5C07B)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  roleName,
                  style: const TextStyle(
                    color: Color(0xFFE5C07B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Tooltip(
            message: 'تسجيل الخروج',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB42318).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB42318).withValues(alpha: 0.6),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'خروج',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// القائمة الجانبية
// ══════════════════════════════════════════════════════════════

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.currentUser,
    required this.isManager,
    required this.onOpenCriminalCases,
    required this.onOpenGis,
    this.approvalService,
    this.onRunNormalization,
    this.onOpenAdminPanel,
    this.onOpenApproval,
    this.onOpenMyRequests,
    this.onOpenDeviceApproval,
    this.onOpenSyncStatus,
  });

  final Map<String, dynamic> currentUser;
  final bool             isManager;
  final VoidCallback     onOpenCriminalCases;
  final VoidCallback     onOpenGis;
  final ApprovalService? approvalService;
  final VoidCallback?    onRunNormalization;
  final VoidCallback?    onOpenAdminPanel;
  final VoidCallback?    onOpenApproval;
  final VoidCallback?    onOpenMyRequests;
  final VoidCallback?    onOpenDeviceApproval;
  final VoidCallback?    onOpenSyncStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: const Color(0xFF0B6B55),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── الرئيسية ─────────────────────────────────
                  _SectionHeader(
                    title: 'الرئيسية',
                    icon:  Icons.home_outlined,
                  ),
                  // المحاضر الجنائية — تحت الرئيسية
                  _SubMenuItem(
                    title: 'المحاضر الجنائية',
                    icon:  Icons.gavel,
                    onTap: onOpenCriminalCases,
                  ),
                  const SizedBox(height: 6),

                  // ── الحجز الإداري ────────────────────────────
                  _MenuItem(title: 'الحجز الإداري',  icon: Icons.account_balance),
                  // ── الشكاوى ──────────────────────────────────
                  _MenuItem(title: 'الشكاوى',         icon: Icons.support_agent_outlined),
                  // ── الإزالات ─────────────────────────────────
                  _MenuItem(title: 'الإزالات',         icon: Icons.cleaning_services_outlined),
                  // ── التقنين — جديد ───────────────────────────
                  _MenuItem(title: 'التقنين',          icon: Icons.folder_special_outlined),
                  // ── إعداد البيانات ───────────────────────────
                  _MenuItem(title: 'إعداد البيانات',   icon: Icons.tune),
                  // ── الحسابات ─────────────────────────────────
                  _MenuItem(title: 'الحسابات',         icon: Icons.calculate_outlined),
                  // ── شبكة المصارف ─────────────────────────────
                  _MenuItem(
                    title: 'شبكة المصارف',
                    icon:  Icons.map_outlined,
                    onTap: onOpenGis,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Colors.white24, height: 1),
                  ),

                  // ── مراجعة الطلبات (مدير) ────────────────────
                  if (isManager && onOpenApproval != null)
                    _MenuItem(
                      title: 'مراجعة الطلبات',
                      icon:  Icons.pending_actions_outlined,
                      onTap: onOpenApproval,
                    ),

                  // ── موافقة الأجهزة (مدير) ────────────────────
                  if (isManager && onOpenDeviceApproval != null)
                    _MenuItem(
                      title: 'موافقة الأجهزة',
                      icon:  Icons.devices_outlined,
                      onTap: onOpenDeviceApproval,
                    ),

                  // ── لوحة التحكم (مدير) ───────────────────────
                  if (isManager && onOpenAdminPanel != null)
                    _MenuItem(
                      title:     'لوحة التحكم',
                      icon:      Icons.admin_panel_settings_outlined,
                      highlight: true,
                      onTap:     onOpenAdminPanel,
                    ),

                  // ── طلباتي (موظف) ─────────────────────────────
                  if (!isManager && onOpenMyRequests != null)
                    _MenuItem(
                      title: 'طلباتي',
                      icon:  Icons.assignment_outlined,
                      onTap: onOpenMyRequests,
                    ),

                  // ── حالة المزامنة (للجميع) ───────────────────
                  _MenuItem(
                    title: 'حالة المزامنة',
                    icon:  Icons.sync_outlined,
                    onTap: onOpenSyncStatus,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── رأس القسم في القائمة (الرئيسية) ──────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String   title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF05352D)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF05352D),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.expand_more, color: Color(0xFF05352D), size: 18),
        ],
      ),
    );
  }
}

// ── عنصر فرعي تحت القسم ──────────────────────────────────────

class _SubMenuItem extends StatelessWidget {
  const _SubMenuItem({
    required this.title,
    required this.icon,
    this.onTap,
  });

  final String    title;
  final IconData  icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 24,
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5C07B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white54, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── عنصر قائمة عادي ───────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.title,
    required this.icon,
    this.highlight = false,
    this.onTap,
  }) : selected = false;

  final String    title;
  final IconData  icon;
  final bool      selected;
  final bool      highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;

    if (selected) {
      bgColor = Colors.white;
      fgColor = const Color(0xFF05352D);
    } else if (highlight) {
      bgColor = const Color(0xFFE5C07B).withValues(alpha: 0.18);
      fgColor = const Color(0xFFE5C07B);
    } else {
      bgColor = Colors.white.withValues(alpha: 0.08);
      fgColor = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: highlight
                ? Border.all(
                    color: const Color(0xFFE5C07B).withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: fgColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (highlight)
                Icon(
                  Icons.admin_panel_settings,
                  color: const Color(0xFFE5C07B).withValues(alpha: 0.7),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── بطاقة إحصائية ──────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color   = const Color(0xFF05352D),
    this.tappable = false,
    this.onTap,
  });

  final String    title;
  final String    value;
  final IconData  icon;
  final Color     color;
  final bool      tappable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 210,
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tappable
              ? color.withValues(alpha: 0.4)
              : const Color(0xFFE5DCC8),
          width: tappable ? 1.5 : 1,
        ),
        boxShadow: tappable
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF4F5B57),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (tappable)
            Icon(Icons.arrow_back_ios_new,
                color: color.withValues(alpha: 0.5), size: 14),
        ],
      ),
    );

    if (!tappable || onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// لوحة التحليلات (Tabbed Analytics Panel)
// ══════════════════════════════════════════════════════════════

class _AnalyticsPanel extends StatefulWidget {
  const _AnalyticsPanel({
    required this.stats,
    required this.isLoading,
    required this.onOpenCriminalCases,
  });

  final Map<String, dynamic> stats;
  final bool                 isLoading;
  final VoidCallback         onOpenCriminalCases;

  @override
  State<_AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends State<_AnalyticsPanel> {
  int _tab = 0;

  static const _tabIcons = <IconData>[
    Icons.calendar_today_outlined,
    Icons.list,
    Icons.person_outline,
    Icons.water_drop_outlined,
    Icons.flag,
  ];

  static const _tabLabels = <String>[
    'بالسنة',
    'نوع المخالفة',
    'الملاحظ',
    'المصرف',
    'الموقف',
  ];

  static const _colors = [
    Color(0xFF0B6B55),
    Color(0xFF1D4ED8),
    Color(0xFFB45309),
    Color(0xFF6B3FA0),
    Color(0xFFB42318),
    Color(0xFF065F46),
    Color(0xFF0369A1),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFF2563EB),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── شريط العنوان والتبويبات ────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F2EA),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                topLeft: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE5DCC8))),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: Color(0xFF05352D), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'تحليل المحاضر الجنائية',
                  style: TextStyle(
                    color: Color(0xFF05352D),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 24),
                // التبويبات
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabLabels.length, (i) {
                        final selected = _tab == i;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => setState(() => _tab = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF05352D)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF05352D)
                                      : const Color(0xFFD1C9B8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _tabIcons[i],
                                    size: 16,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _tabLabels[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // زر الانتقال للمحاضر
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF05352D),
                    side: const BorderSide(color: Color(0xFF0B6B55)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                  ),
                  onPressed: widget.onOpenCriminalCases,
                  icon: const Icon(Icons.gavel, size: 16),
                  label: const Text('عرض المحاضر', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),

          // ── محتوى التبويب ──────────────────────────────────────
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0B6B55),
                    ),
                  )
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0: return _buildYearChart();
      case 1: return _buildHBarChart('by_vtype',    'نوع المخالفة',  _colors[0]);
      case 2: return _buildHBarChart('by_observer', 'الملاحظ',       _colors[1]);
      case 3: return _buildHBarChart('by_drain',    'المصرف',        _colors[3]);
      case 4: return _buildStatusChart();
      default: return const SizedBox();
    }
  }

  // ── رسم بياني عمودي: المحاضر بالسنة ────────────────────────
  Widget _buildYearChart() {
    final data = (widget.stats['by_year'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (data.isEmpty) {
      return _EmptyChart(msg: 'لا توجد بيانات للسنوات');
    }

    final maxCount = data.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
    final total    = data.map((e) => e['count'] as int).fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ملخص ────────────────────────────────────────────
          _ChartSummaryRow(items: [
            _SummaryItem('إجمالي المحاضر', total.toString(), const Color(0xFF0B6B55)),
            _SummaryItem('أكثر سنة', () {
              final m = data.reduce((a, b) => (a['count'] as int) > (b['count'] as int) ? a : b);
              return '${m['year']} (${m['count']})';
            }(), const Color(0xFF1D4ED8)),
            _SummaryItem('أقل سنة', () {
              final m = data.reduce((a, b) => (a['count'] as int) < (b['count'] as int) ? a : b);
              return '${m['year']} (${m['count']})';
            }(), const Color(0xFFB45309)),
          ]),
          const SizedBox(height: 16),

          // ── الرسم البياني العمودي ─────────────────────────
          Expanded(
            child: LayoutBuilder(builder: (ctx, bc) {
              final barW = ((bc.maxWidth - 40) / data.length).clamp(32.0, 80.0);
              final chartH = bc.maxHeight - 50;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: barW * data.length + 40,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(width: 20),
                            ...data.map((d) {
                              final cnt  = d['count'] as int;
                              final year = d['year']  as int;
                              final barH = (chartH * cnt / maxCount).clamp(4.0, chartH);
                              final pct  = (cnt * 100 / total).toStringAsFixed(1);
                              final colorIdx = data.indexOf(d) % _colors.length;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      cnt.toString(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                    Text(
                                      '$pct%',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Tooltip(
                                      message: '$year: $cnt محضر ($pct%)',
                                      child: Container(
                                        width: barW - 6,
                                        height: barH,
                                        decoration: BoxDecoration(
                                          color: _colors[colorIdx],
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE5DCC8)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 20),
                          ...data.map((d) {
                            final year = (d['year'] as int).toString();
                            return SizedBox(
                              width: barW,
                              child: Text(
                                year,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF374151),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── رسم بياني أفقي: نوع المخالفة / الملاحظ / المصرف ────────
  Widget _buildHBarChart(String key, String labelTitle, Color color) {
    final data = (widget.stats[key] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (data.isEmpty) {
      return _EmptyChart(msg: 'لا توجد بيانات لـ$labelTitle');
    }

    final maxCount = data.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
    final total    = data.map((e) => e['count'] as int).fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartSummaryRow(items: [
            _SummaryItem('إجمالي', total.toString(), color),
            _SummaryItem('الأعلى', () {
              final m = data.first;
              final pct = (m['count'] * 100 / total).toStringAsFixed(1);
              return '${m['name']} ($pct%)';
            }(), _colors[1]),
            _SummaryItem('عدد التصنيفات', data.length.toString(), _colors[3]),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final d    = data[i];
                final cnt  = d['count'] as int;
                final name = d['name']  as String;
                final pct  = (cnt * 100 / total).toStringAsFixed(1);
                final barColor = _colors[i % _colors.length];

                return LayoutBuilder(builder: (ctx2, bc) {
                  final barW = maxCount > 0
                      ? (bc.maxWidth - 180) * cnt / maxCount
                      : 0.0;
                  return Row(
                    children: [
                      // التسمية
                      SizedBox(
                        width: 160,
                        child: Text(
                          name,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // الشريط
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              height: 24,
                              width: barW.clamp(4.0, bc.maxWidth - 180),
                              decoration: BoxDecoration(
                                color: barColor.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // القيمة والنسبة
                      SizedBox(
                        width: 70,
                        child: Text(
                          '$cnt ($pct%)',
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── رسم بياني: موقف المحاضر ─────────────────────────────────
  Widget _buildStatusChart() {
    final data = (widget.stats['by_status'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (data.isEmpty) {
      return _EmptyChart(msg: 'لا توجد بيانات للمواقف');
    }

    final total = data.map((e) => e['count'] as int).fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // دوائر ملخص
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: data.asMap().entries.map((e) {
              final i   = e.key;
              final d   = e.value;
              final cnt = d['count'] as int;
              final pct = total > 0 ? (cnt * 100 / total).toStringAsFixed(1) : '0';
              final c   = _colors[i % _colors.length];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cnt.toString(),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: c,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(fontSize: 12, color: c),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 130,
                      child: Text(
                        d['name'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // شرائط النسب
          Expanded(
            child: ListView.separated(
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final d    = data[i];
                final cnt  = d['count'] as int;
                final name = d['name']  as String;
                final pct  = total > 0 ? cnt / total : 0.0;
                final c    = _colors[i % _colors.length];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        Text(
                          '$cnt (${(pct * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: c,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LayoutBuilder(builder: (_, bc) => Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: bc.maxWidth * pct,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── ملخص أعلى الرسم البياني ───────────────────────────────────

class _ChartSummaryRow extends StatelessWidget {
  const _ChartSummaryRow({required this.items});
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: item.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: TextStyle(fontSize: 12, color: item.color),
            ),
            const SizedBox(width: 8),
            Text(
              item.value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color  color;
}

// ── حاوية فارغة ───────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 48, color: Color(0xFFD1C9B8)),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── زر إجراء ──────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String    title;
  final String    subtitle;
  final IconData  icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F2EA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5DCC8)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0B6B55).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF0B6B55), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF05352D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF0B6B55), size: 16),
          ],
        ),
      ),
    );
  }
}
