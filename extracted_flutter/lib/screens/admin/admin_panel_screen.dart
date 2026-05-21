// ============================================================
// admin_panel_screen.dart
// لوحة تحكم المدير — 3 تبويبات
//   1. إدارة المستخدمين
//   2. حالة الحسابات
//   3. سجل النشاط
// ============================================================
// الاستخدام: ضعه في lib/screens/admin/
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── ألوان المشروع الثابتة ──────────────────────────────────
const _kDark   = Color(0xFF05352D);
const _kGreen  = Color(0xFF0B6B55);
const _kBg     = Color(0xFFF5F2EA);
const _kGold   = Color(0xFFE5C07B);
const _kBorder = Color(0xFFE5DCC8);
const _kRed    = Color(0xFFB42318);

// ===========================================================
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key, required this.db});
  final Database db;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: _kDark,
            foregroundColor: Colors.white,
            title: const Text('لوحة التحكم — إدارة النظام'),
            bottom: const TabBar(
              labelColor: _kGold,
              unselectedLabelColor: Colors.white60,
              indicatorColor: _kGold,
              tabs: [
                Tab(icon: Icon(Icons.people_outline),  text: 'إدارة الحسابات'),
                Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'حالة الحسابات'),
                Tab(icon: Icon(Icons.history),          text: 'سجل النشاط'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _UserManagementTab(db: db),
              _AccountStatusTab(db: db),
              _ActivityHistoryTab(db: db),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// ── Tab 1: إدارة المستخدمين ────────────────────────────────
// ===========================================================
class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab({required this.db});
  final Database db;
  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final rows = await widget.db.query('users', orderBy: 'id ASC');
    if (!mounted) return;
    setState(() {
      users = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      loading = false;
    });
  }

  // ── حوار إضافة/تعديل مستخدم ──────────────────────────────
  Future<void> _openDialog({Map<String, dynamic>? user}) async {
    final nameCtrl = TextEditingController(text: user?['employee_name'] ?? '');
    final userCtrl = TextEditingController(text: user?['username'] ?? '');
    final passCtrl = TextEditingController();
    String role = user?['role'] ?? 'employee';
    String roleLabel = user?['role_name'] ?? 'موظف';
    bool showPass = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(user == null ? 'إضافة مستخدم جديد' : 'تعديل بيانات المستخدم'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field('الاسم الكامل', nameCtrl),
                  const SizedBox(height: 14),
                  _field('اسم المستخدم', userCtrl,
                      enabled: user == null),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passCtrl,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: user == null
                          ? 'كلمة المرور'
                          : 'كلمة المرور الجديدة (اتركها فارغة للإبقاء)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setS(() => showPass = !showPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'الدور الوظيفي',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'employee', child: Text('موظف')),
                      DropdownMenuItem(value: 'manager',  child: Text('مدير')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setS(() {
                        role = v;
                        roleLabel = v == 'manager' ? 'مدير الهندسة' : 'موظف';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kGreen),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      userCtrl.text.trim().isEmpty) {
                    return;
                  }
                  if (user == null && passCtrl.text.trim().isEmpty) return;

                  try {
                    if (user == null) {
                      // إضافة
                      await widget.db.insert('users', {
                        'employee_name': nameCtrl.text.trim(),
                        'username': userCtrl.text.trim(),
                        'password_hash': passCtrl.text.trim(),
                        'role': role,
                        'role_name': roleLabel,
                        'is_active': 1,
                      });
                    } else {
                      // تعديل
                      final data = <String, dynamic>{
                        'employee_name': nameCtrl.text.trim(),
                        'role': role,
                        'role_name': roleLabel,
                      };
                      if (passCtrl.text.trim().isNotEmpty) {
                        data['password_hash'] = passCtrl.text.trim();
                      }
                      await widget.db.update(
                        'users',
                        data,
                        where: 'id = ?',
                        whereArgs: [user['id']],
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('خطأ: $e'),
                          backgroundColor: _kRed,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  // ── تفعيل/تعطيل حساب ─────────────────────────────────────
  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final current = (user['is_active'] as int? ?? 1);
    final next = current == 1 ? 0 : 1;
    final action = next == 1 ? 'تفعيل' : 'تعطيل';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action الحساب'),
          content: Text(
            'هل تريد $action حساب "${user['employee_name']}"؟',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: next == 1 ? _kGreen : _kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.db.update(
      'users',
      {'is_active': next},
      where: 'id = ?',
      whereArgs: [user['id']],
    );
    _load();
  }

  // ── حذف مستخدم ───────────────────────────────────────────
  Future<void> _delete(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحساب'),
          content: Text(
            'هل تريد حذف حساب "${user['employee_name']}" نهائياً؟\nلا يمكن التراجع عن هذه العملية.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائي'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.db.delete('users', where: 'id = ?', whereArgs: [user['id']]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة مستخدم'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي الحسابات: ${users.length}',
                    style: const TextStyle(
                        color: _kDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(_kDark),
                          columns: const [
                            DataColumn(label: Text('#', style: TextStyle(color: Colors.white))),
                            DataColumn(label: Text('الاسم', style: TextStyle(color: Colors.white))),
                            DataColumn(label: Text('المستخدم', style: TextStyle(color: Colors.white))),
                            DataColumn(label: Text('الدور', style: TextStyle(color: Colors.white))),
                            DataColumn(label: Text('الحالة', style: TextStyle(color: Colors.white))),
                            DataColumn(label: Text('إجراءات', style: TextStyle(color: Colors.white))),
                          ],
                          rows: users.map((u) {
                            final active = (u['is_active'] as int? ?? 1) == 1;
                            return DataRow(cells: [
                              DataCell(Text(u['id'].toString())),
                              DataCell(Text(u['employee_name'] ?? '-')),
                              DataCell(Text(u['username'] ?? '-')),
                              DataCell(_RoleBadge(role: u['role'] ?? 'employee', label: u['role_name'] ?? 'موظف')),
                              DataCell(
                                GestureDetector(
                                  onTap: () => _toggleActive(u),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? _kGreen.withValues(alpha: 0.12)
                                          : _kRed.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: active ? _kGreen : _kRed),
                                    ),
                                    child: Text(
                                      active ? 'مفعّل' : 'معطّل',
                                      style: TextStyle(
                                          color: active ? _kGreen : _kRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    tooltip: 'تعديل',
                                    icon: const Icon(Icons.edit_outlined, color: _kDark),
                                    onPressed: () => _openDialog(user: u),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(Icons.delete_outline, color: _kRed),
                                    onPressed: () => _delete(u),
                                  ),
                                ],
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static TextField _field(String label, TextEditingController ctrl, {bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ===========================================================
// ── Tab 2: حالة الحسابات ───────────────────────────────────
// ===========================================================
class _AccountStatusTab extends StatefulWidget {
  const _AccountStatusTab({required this.db});
  final Database db;
  @override
  State<_AccountStatusTab> createState() => _AccountStatusTabState();
}

class _AccountStatusTabState extends State<_AccountStatusTab> {
  List<Map<String, dynamic>> status = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final rows = await widget.db.rawQuery('''
      SELECT
        u.id,
        u.username,
        u.employee_name,
        u.role,
        u.role_name,
        u.is_active,
        s.login_at  AS last_login,
        s.logout_at AS last_logout
      FROM users u
      LEFT JOIN user_sessions s ON s.id = (
        SELECT MAX(id) FROM user_sessions WHERE user_id = u.id
      )
      ORDER BY u.id
    ''');
    if (!mounted) return;
    setState(() {
      status = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = status.where((u) {
      return u['last_login'] != null &&
          (u['last_logout'] == null || u['last_logout'].toString().isEmpty);
    }).length;

    return loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatChip(
                      label: 'متصل الآن',
                      value: '$online',
                      color: _kGreen,
                      icon: Icons.wifi,
                    ),
                    const SizedBox(width: 16),
                    _StatChip(
                      label: 'إجمالي الحسابات',
                      value: '${status.length}',
                      color: _kDark,
                      icon: Icons.people_outline,
                    ),
                    const SizedBox(width: 16),
                    _StatChip(
                      label: 'حسابات مفعّلة',
                      value: '${status.where((u) => (u['is_active'] as int? ?? 1) == 1).length}',
                      color: _kGold,
                      icon: Icons.check_circle_outline,
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: status.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final u = status[i];
                      final active = (u['is_active'] as int? ?? 1) == 1;
                      final isOnline = u['last_login'] != null &&
                          (u['last_logout'] == null ||
                              u['last_logout'].toString().isEmpty);
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isOnline
                                ? _kGreen.withValues(alpha: 0.5)
                                : _kBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? _kGreen.withValues(alpha: 0.12)
                                    : Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isOnline ? Icons.wifi : Icons.wifi_off,
                                color: isOnline ? _kGreen : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u['employee_name'] ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _kDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${u['username']} — ${u['role_name'] ?? '-'}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  if (u['last_login'] != null)
                                    Text(
                                      'آخر دخول: ${_fmt(u['last_login']?.toString())}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _StatusBadge(
                                  label: isOnline ? 'متصل' : 'غير متصل',
                                  color: isOnline ? _kGreen : Colors.grey,
                                ),
                                const SizedBox(height: 6),
                                _StatusBadge(
                                  label: active ? 'مفعّل' : 'معطّل',
                                  color: active ? _kDark : _kRed,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
  }

  static String _fmt(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}  ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ===========================================================
// ── Tab 3: سجل النشاط ──────────────────────────────────────
// ===========================================================
class _ActivityHistoryTab extends StatefulWidget {
  const _ActivityHistoryTab({required this.db});
  final Database db;
  @override
  State<_ActivityHistoryTab> createState() => _ActivityHistoryTabState();
}

class _ActivityHistoryTabState extends State<_ActivityHistoryTab> {
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  String? selectedUserId;
  String period = 'week';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final u = await db.query('users', orderBy: 'employee_name');
    users = u.map((r) => Map<String, dynamic>.from(r)).toList();
    await _load();
  }

  Database get db => widget.db;

  Future<void> _load() async {
    setState(() => loading = true);

    String where = '1=1';
    final args = <dynamic>[];

    if (selectedUserId != null) {
      where += ' AND al.user_id = ?';
      args.add(int.tryParse(selectedUserId!) ?? 0);
    }

    if (period == 'week') {
      where += " AND al.created_at >= datetime('now','-7 days','localtime')";
    } else if (period == 'month') {
      where += " AND al.created_at >= datetime('now','-30 days','localtime')";
    }

    final rows = await db.rawQuery('''
      SELECT al.*, u.employee_name
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      WHERE $where
      ORDER BY al.id DESC
      LIMIT 500
    ''', args);

    if (!mounted) return;
    setState(() {
      logs = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      loading = false;
    });
  }

  Future<void> _archive() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fname =
          'activity_archive_${now.year}-${_p(now.month)}-${_p(now.day)}.json';
      final file = File('${dir.path}${Platform.pathSeparator}$fname');
      await file.writeAsString(jsonEncode(logs));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الأرشفة في:\n${file.path}'),
          backgroundColor: _kGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الأرشفة: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _importArchive() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ضع ملف JSON في نفس مجلد الأرشيف وأعد تشغيل الاستيراد.',
        ),
      ),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  static String _opLabel(String op) {
    switch (op) {
      case 'create':  return 'إضافة';
      case 'update':  return 'تعديل';
      case 'delete':  return 'حذف';
      case 'approve': return 'اعتماد';
      case 'reject':  return 'رفض';
      case 'login':   return 'دخول';
      case 'logout':  return 'خروج';
      default:        return op;
    }
  }

  static Color _opColor(String op) {
    switch (op) {
      case 'create':  return _kGreen;
      case 'approve': return _kGreen;
      case 'delete':  return _kRed;
      case 'reject':  return _kRed;
      case 'update':  return Colors.orange;
      case 'login':   return _kDark;
      case 'logout':  return Colors.grey;
      default:        return Colors.blueGrey;
    }
  }

  static IconData _opIcon(String op) {
    switch (op) {
      case 'create':  return Icons.add_circle_outline;
      case 'update':  return Icons.edit_outlined;
      case 'delete':  return Icons.delete_outline;
      case 'approve': return Icons.check_circle_outline;
      case 'reject':  return Icons.cancel_outlined;
      case 'login':   return Icons.login;
      case 'logout':  return Icons.logout;
      default:        return Icons.info_outline;
    }
  }

  static String _fmtDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}\n${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'المستخدم',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ...users.map((u) => DropdownMenuItem(
                          value: u['id'].toString(),
                          child: Text(u['employee_name'] ?? '-'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => selectedUserId = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week',  label: Text('أسبوع')),
                  ButtonSegment(value: 'month', label: Text('شهر')),
                  ButtonSegment(value: 'all',   label: Text('الكل')),
                ],
                selected: {period},
                onSelectionChanged: (s) {
                  setState(() => period = s.first);
                  _load();
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? _kGreen
                        : null,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : _kDark,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${logs.length} سجل',
                style: const TextStyle(
                    color: _kDark, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: logs.isEmpty ? null : _archive,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('أرشفة'),
                style: OutlinedButton.styleFrom(foregroundColor: _kGreen),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _importArchive,
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('استيراد أرشيف'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد سجلات في هذه الفترة',
                          style: TextStyle(
                              fontSize: 18,
                              color: _kDark,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          final op = log['operation']?.toString() ?? '';
                          final color = _opColor(op);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_opIcon(op), color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: color),
                                            ),
                                            child: Text(
                                              _opLabel(op),
                                              style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            log['employee_name']?.toString() ??
                                                log['user_name']?.toString() ??
                                                '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'الجدول: ${log['target_table'] ?? '-'}'
                                        '${log['target_id'] != null ? "  #${log['target_id']}" : ""}',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _fmtDate(log['created_at']?.toString()),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// ── مكوّنات مساعدة ─────────────────────────────────────────
// ===========================================================

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.label});
  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isManager = role == 'manager';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isManager ? _kGold : _kDark).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isManager ? _kGold : _kDark),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isManager ? _kGold : _kDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
