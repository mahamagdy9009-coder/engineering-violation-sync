// ============================================================
// sheet_field.dart
// حقل إدخال موحّد يُستخدم في صحيفة المخالفة (عرض / إضافة / تعديل)
// ضعه في: lib/widgets/sheet_field.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── ألوان الثيم ──────────────────────────────────────────────
const _kDarkGreen  = Color(0xFF05352D);
const _kMidGreen   = Color(0xFF0B6B55);
const _kCream      = Color(0xFFF5F2EA);
const _kGold       = Color(0xFFE5C07B);
const _kBorderView = Color(0xFFDDD8CC);
const _kBorderEdit = Color(0xFF0B6B55);

/// حقل نص عادي بعنوان فوقه
class SheetTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool isRequired;

  const SheetTextField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = true,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.onTap,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── العنوان ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isRequired && !readOnly)
              const Text(' *',
                  style: TextStyle(color: Color(0xFFB42318), fontSize: 12)),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: readOnly ? const Color(0xFF6B7280) : _kDarkGreen,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ── حقل الإدخال ──────────────────────────────────────
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          onTap: onTap,
          validator: isRequired && !readOnly
              ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null
              : validator,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1A2E1A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: readOnly ? null : (hint ?? ''),
            hintStyle: const TextStyle(
                fontSize: 12, color: Color(0xFFADB5BD)),
            filled: true,
            fillColor: readOnly ? _kCream : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: _border(_kBorderView),
            enabledBorder: _border(readOnly ? _kBorderView : _kBorderEdit),
            focusedBorder: _border(_kGold, width: 1.5),
            errorBorder: _border(const Color(0xFFB42318)),
            focusedErrorBorder: _border(const Color(0xFFB42318), width: 1.5),
            disabledBorder: _border(_kBorderView),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ──────────────────────────────────────────────────────────────
/// حقل قائمة منسدلة (Dropdown)
class SheetDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final bool readOnly;
  final void Function(T?)? onChanged;
  final bool isRequired;

  const SheetDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.readOnly = true,
    this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    // في وضع القراءة نعرض قيمة نصية فقط
    if (readOnly) {
      final label2 = items
          .where((i) => i.value == value)
          .map((i) => (i.child as Text?)?.data ?? '-')
          .firstOrNull;
      return SheetTextField(
        label: label,
        controller: TextEditingController(text: label2 ?? '-'),
        readOnly: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isRequired)
              const Text(' *',
                  style: TextStyle(color: Color(0xFFB42318), fontSize: 12)),
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kDarkGreen,
                ),
                textDirection: TextDirection.rtl),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          alignment: AlignmentDirectional.centerEnd,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: _border(_kBorderView),
            enabledBorder: _border(_kBorderEdit),
            focusedBorder: _border(_kGold, width: 1.5),
          ),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1A2E1A), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ──────────────────────────────────────────────────────────────
/// حقل تاريخ مع أيقونة تقويم
class SheetDateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final bool isRequired;

  const SheetDateField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = true,
    this.isRequired = false,
  });

  Future<void> _pick(BuildContext ctx) async {
    final now = DateTime.now();
    DateTime? initial;
    try {
      if (controller.text.trim().isNotEmpty) {
        initial = DateTime.tryParse(controller.text.replaceAll('\\', '-'));
      }
    } catch (_) {}
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text =
          '${picked.year}\\${picked.month.toString().padLeft(2, '0')}\\${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetTextField(
      label: label,
      controller: controller,
      readOnly: readOnly,
      isRequired: isRequired,
      hint: 'YYYY\\MM\\DD',
      onTap: readOnly ? null : () => _pick(context),
    );
  }
}

// ──────────────────────────────────────────────────────────────
/// حقل مالي (أرقام + "جنيه" كـ suffix)
class SheetMoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final bool isRequired;

  const SheetMoneyField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = true,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: readOnly ? const Color(0xFF6B7280) : _kDarkGreen,
            ),
            textDirection: TextDirection.rtl),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          ],
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1A2E1A), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            suffixText: 'جنيه',
            suffixStyle: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7280)),
            filled: true,
            fillColor: readOnly ? _kCream : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: _border(_kBorderView),
            enabledBorder:
                _border(readOnly ? _kBorderView : _kBorderEdit),
            focusedBorder: _border(_kGold, width: 1.5),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ──────────────────────────────────────────────────────────────
/// بطاقة قسم مع أيقونة وعنوان
class SheetSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? iconColor;

  const SheetSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E4DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── رأس القسم ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _kDarkGreen.withValues(alpha: 0.04),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE8E4DC)),
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kDarkGreen,
                    ),
                    textDirection: TextDirection.rtl),
                const SizedBox(width: 8),
                Icon(icon, color: iconColor ?? _kMidGreen, size: 18),
              ],
            ),
          ),
          // ── محتوى القسم ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
