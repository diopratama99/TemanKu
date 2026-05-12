import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Currency input field with auto-formatting
/// Fixes M1: Real-time validation and formatting
class CurrencyFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? Function(String?)? validator;
  final bool enabled;
  final IconData? prefixIcon;

  const CurrencyFormField({
    required this.controller,
    required this.label,
    this.helperText,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    super.key,
  });

  @override
  State<CurrencyFormField> createState() => _CurrencyFormFieldState();
}

class _CurrencyFormFieldState extends State<CurrencyFormField> {
  final _formatter = NumberFormat.currency(
    locale: 'id',
    symbol: '',
    decimalDigits: 0,
  );
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_formatInput);
  }

  void _formatInput() {
    if (_isFormatting) return;
    _isFormatting = true;

    final text = widget.controller.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.isEmpty) {
      _isFormatting = false;
      return;
    }

    final value = int.tryParse(text);
    if (value != null) {
      final formatted = _formatter.format(value);
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    _isFormatting = false;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.label}. Masukkan jumlah dalam Rupiah',
      textField: true,
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: 'Rp ',
          prefixIcon: Icon(widget.prefixIcon ?? Icons.attach_money),
          helperText: widget.helperText ?? 'Masukkan jumlah dalam Rupiah',
          helperMaxLines: 2,
        ),
        validator: widget.validator,
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_formatInput);
    super.dispose();
  }
}

/// Password field with visibility toggle
class PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? Function(String?)? validator;
  final bool showStrengthIndicator;

  const PasswordFormField({
    required this.controller,
    required this.label,
    this.helperText,
    this.validator,
    this.showStrengthIndicator = false,
    super.key,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscureText = true;
  PasswordStrength _strength = PasswordStrength.weak;

  @override
  void initState() {
    super.initState();
    if (widget.showStrengthIndicator) {
      widget.controller.addListener(_checkStrength);
    }
  }

  void _checkStrength() {
    final password = widget.controller.text;
    setState(() {
      _strength = _calculateStrength(password);
    });
  }

  PasswordStrength _calculateStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;
    if (password.length < 6) return PasswordStrength.weak;

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  Color _getStrengthColor() {
    switch (_strength) {
      case PasswordStrength.weak:
        return AppTheme.expenseColor;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return AppTheme.incomeColor;
    }
  }

  String _getStrengthLabel() {
    switch (_strength) {
      case PasswordStrength.weak:
        return 'Lemah';
      case PasswordStrength.medium:
        return 'Sedang';
      case PasswordStrength.strong:
        return 'Kuat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              '${widget.label}. ${_obscureText ? 'Tersembunyi' : 'Terlihat'}',
          textField: true,
          obscured: _obscureText,
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscureText,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: widget.label,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: widget.helperText,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                  semanticLabel: _obscureText
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
            validator: widget.validator,
          ),
        ),

        // Password strength indicator
        if (widget.showStrengthIndicator &&
            widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _strength == PasswordStrength.weak
                      ? 0.33
                      : _strength == PasswordStrength.medium
                      ? 0.66
                      : 1.0,
                  backgroundColor: AppTheme.textDisabled.withOpacity(0.2),
                  color: _getStrengthColor(),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                _getStrengthLabel(),
                style: TextStyle(
                  fontSize: 12,
                  color: _getStrengthColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    if (widget.showStrengthIndicator) {
      widget.controller.removeListener(_checkStrength);
    }
    super.dispose();
  }
}

enum PasswordStrength { weak, medium, strong }

/// Date picker field
class DatePickerField extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    required this.selectedDate,
    required this.onDateChanged,
    required this.label,
    this.firstDate,
    this.lastDate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMMM yyyy', 'id').format(selectedDate);

    return Semantics(
      label: '$label. Tanggal terpilih: $formattedDate',
      button: true,
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: formattedDate,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: firstDate ?? DateTime(2000),
            lastDate: lastDate ?? DateTime(2100),
            locale: const Locale('id', 'ID'),
            helpText: 'Pilih Tanggal',
            cancelText: 'Batal',
            confirmText: 'Pilih',
          );

          if (picked != null && picked != selectedDate) {
            onDateChanged(picked);
          }
        },
      ),
    );
  }
}

/// Dropdown field with search
class CategoryDropdownField extends StatelessWidget {
  final int? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int?> onChanged;
  final String label;
  final String? helperText;
  final String? Function(int?)? validator;

  const CategoryDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.helperText,
    this.validator,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DropdownButtonFormField<int>(
        value: value,
        items: items.map((item) {
          final emoji = (item['emoji'] as String?) ?? '💰';
          final name = item['name'] as String;

          return DropdownMenuItem<int>(
            value: item['id'] as int,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: AppTheme.space8),
                Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.category),
          helperText: helperText,
        ),
        validator: validator,
        dropdownColor: AppTheme.cardColor,
        isExpanded: true,
      ),
    );
  }
}
