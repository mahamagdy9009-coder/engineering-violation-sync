import 'package:flutter/material.dart';

import '../../database/database_service.dart';

class CaseFormScreen extends StatefulWidget {
  const CaseFormScreen({
    super.key,
    required this.filterOptions,
    this.currentUser,
    this.item,
  });

  final Map<String, dynamic>? currentUser;
  final Map<String, dynamic>? item;
  final Map<String, List<Map<String, dynamic>>> filterOptions;

  bool get isEdit => item != null;

  @override
  State<CaseFormScreen> createState() => _CaseFormScreenState();
}

class _CaseFormScreenState extends State<CaseFormScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController reportNumberController;
  late final TextEditingController reportYearController;
  late final TextEditingController reportDateController;
  late final TextEditingController removalDecisionController;
  late final TextEditingController judicialNumberController;
  late final TextEditingController offenderNameController;
  late final TextEditingController nationalIdController;
  late final TextEditingController kilometerController;
  late final TextEditingController areaController;
  late final TextEditingController removalDateController;
  late final TextEditingController reportValueController;
  late final TextEditingController paidAmountController;

  int? drainId;
  int? violationTypeId;
  int? observerId;
  int? caseStatusId;
  int? adminSeizureStatusId;
  int? dissipationStatusId;
  int? paymentStatusId;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final item = widget.item ?? const <String, dynamic>{};
    reportNumberController = _controller(item['report_number']);
    reportYearController = _controller(item['report_year']);
    reportDateController = _controller(item['report_date']);
    removalDecisionController = _controller(item['removal_decision_number']);
    judicialNumberController = _controller(item['judicial_number']);
    offenderNameController = _controller(item['offender_name']);
    nationalIdController = _controller(item['offender_national_id']);
    kilometerController = _controller(item['kilometer_location']);
    areaController = _controller(item['area']);
    removalDateController = _controller(item['removal_date']);
    reportValueController = _controller(item['report_value']);
    paidAmountController = _controller(item['paid_amount']);

    drainId = _intValue(item['drain_id']);
    violationTypeId = _intValue(item['violation_type_id']);
    observerId = _intValue(item['observer_id']);
    caseStatusId = _intValue(item['case_status_id']);
    adminSeizureStatusId = _intValue(item['admin_seizure_status_id']);
    dissipationStatusId = _intValue(item['dissipation_status_id']);
    paymentStatusId = _intValue(item['payment_status_id']);
  }

  @override
  void dispose() {
    reportNumberController.dispose();
    reportYearController.dispose();
    reportDateController.dispose();
    removalDecisionController.dispose();
    judicialNumberController.dispose();
    offenderNameController.dispose();
    nationalIdController.dispose();
    kilometerController.dispose();
    areaController.dispose();
    removalDateController.dispose();
    reportValueController.dispose();
    paidAmountController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() => saving = true);

    final after = {
      'report_number': _intFromText(reportNumberController.text),
      'report_year': _intFromText(reportYearController.text),
      'report_date': _emptyToNull(reportDateController.text),
      'removal_decision_number': _emptyToNull(removalDecisionController.text),
      'judicial_number': _emptyToNull(judicialNumberController.text),
      'offender_name': _emptyToNull(offenderNameController.text),
      'offender_national_id': _emptyToNull(nationalIdController.text),
      'drain_id': drainId,
      'kilometer_location': _emptyToNull(kilometerController.text),
      'violation_type_id': violationTypeId,
      'area': _doubleFromText(areaController.text),
      'observer_id': observerId,
      'case_status_id': caseStatusId,
      'removal_date': _emptyToNull(removalDateController.text),
      'report_value': _doubleFromText(reportValueController.text) ?? 0,
      'admin_seizure_status_id': adminSeizureStatusId,
      'dissipation_status_id': dissipationStatusId,
      'payment_status_id': paymentStatusId,
      'paid_amount': _doubleFromText(paidAmountController.text) ?? 0,
    };

    try {
      await DatabaseService.submitCaseChangeRequest(
        requestType: widget.isEdit ? 'update' : 'create',
        targetId: _intValue(widget.item?['id']),
        before: widget.isEdit ? widget.item : null,
        after: after,
        requestedBy: _intValue(widget.currentUser?['id']),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب للمدير للمراجعة'),
          backgroundColor: Color(0xFF0B6B55),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ الطلب. حاول مرة أخرى'),
          backgroundColor: Color(0xFFB42318),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'تعديل محضر' : 'تسجيل محضر جديد';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF05352D),
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'بيانات المحضر',
                  children: [
                    _TextInput(
                      label: 'رقم المحضر',
                      controller: reportNumberController,
                      requiredField: true,
                      numeric: true,
                    ),
                    _TextInput(
                      label: 'سنة المحضر',
                      controller: reportYearController,
                      requiredField: true,
                      numeric: true,
                    ),
                    _TextInput(
                      label: 'تاريخ المحضر',
                      controller: reportDateController,
                      hint: 'مثال: 2026-05-09',
                    ),
                    _TextInput(
                      label: 'رقم قرار الإزالة',
                      controller: removalDecisionController,
                    ),
                    _TextInput(
                      label: 'الرقم القضائي',
                      controller: judicialNumberController,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'بيانات المخالف والمخالفة',
                  children: [
                    _TextInput(
                      label: 'اسم المخالف',
                      controller: offenderNameController,
                      requiredField: true,
                    ),
                    _TextInput(
                      label: 'الرقم القومي',
                      controller: nationalIdController,
                    ),
                    _DropdownInput(
                      label: 'المصرف',
                      value: drainId,
                      options: _options('drains'),
                      onChanged: (value) => setState(() => drainId = value),
                    ),
                    _TextInput(
                      label: 'الموقع الكيلومتري',
                      controller: kilometerController,
                    ),
                    _DropdownInput(
                      label: 'نوع المخالفة',
                      value: violationTypeId,
                      options: _options('violation_types'),
                      onChanged: (value) =>
                          setState(() => violationTypeId = value),
                    ),
                    _TextInput(
                      label: 'المساحة',
                      controller: areaController,
                      numeric: true,
                    ),
                    _DropdownInput(
                      label: 'اسم الملاحظ',
                      value: observerId,
                      options: _options('observers'),
                      onChanged: (value) => setState(() => observerId = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'الموقف والحسابات',
                  children: [
                    _DropdownInput(
                      label: 'موقف المحضر',
                      value: caseStatusId,
                      options: _options('case_statuses'),
                      onChanged: (value) =>
                          setState(() => caseStatusId = value),
                    ),
                    _TextInput(
                      label: 'تاريخ الإزالة',
                      controller: removalDateController,
                      hint: 'مثال: 2026-05-09',
                    ),
                    _TextInput(
                      label: 'قيمة المحضر',
                      controller: reportValueController,
                      numeric: true,
                    ),
                    _DropdownInput(
                      label: 'موقف الحجز الإداري',
                      value: adminSeizureStatusId,
                      options: _options('admin_seizure_statuses'),
                      onChanged: (value) =>
                          setState(() => adminSeizureStatusId = value),
                    ),
                    _DropdownInput(
                      label: 'موقف التبديد',
                      value: dissipationStatusId,
                      options: _options('dissipation_statuses'),
                      onChanged: (value) =>
                          setState(() => dissipationStatusId = value),
                    ),
                    _DropdownInput(
                      label: 'الموقف من السداد',
                      value: paymentStatusId,
                      options: _options('payment_statuses'),
                      onChanged: (value) =>
                          setState(() => paymentStatusId = value),
                    ),
                    _TextInput(
                      label: 'ما تم سداده',
                      controller: paidAmountController,
                      numeric: true,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: saving ? null : submit,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        widget.isEdit
                            ? 'إرسال طلب التعديل للمدير'
                            : 'إرسال طلب الإضافة للمدير',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _options(String key) {
    return widget.filterOptions[key] ?? const <Map<String, dynamic>>[];
  }

  static TextEditingController _controller(dynamic value) {
    return TextEditingController(text: value?.toString() ?? '');
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _intFromText(String value) {
    return int.tryParse(value.trim());
  }

  static double? _doubleFromText(String value) {
    return double.tryParse(value.trim());
  }

  static String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF05352D),
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: children),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.label,
    required this.controller,
    this.hint,
    this.requiredField = false,
    this.numeric = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool requiredField;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<Map<String, dynamic>> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final availableValue = options.any((option) => option['id'] == value)
        ? value
        : null;

    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<int>(
        initialValue: availableValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('غير محدد')),
          ...options.map(
            (option) => DropdownMenuItem<int>(
              value: option['id'] as int,
              child: Text(
                option['name']?.toString() ?? '-',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
