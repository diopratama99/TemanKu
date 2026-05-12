import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

/// Editorial transaction composer — magazine "TULIS" page.
class AddTransactionPage extends StatefulWidget {
  final bool showHistoryButton;
  final bool isModal;

  const AddTransactionPage({
    super.key,
    this.showHistoryButton = true,
    this.isModal = false,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  DateTime _date = DateTime.now();
  String _type = 'expense';
  int? _categoryId;
  final _amount = TextEditingController();
  final _payee = TextEditingController();
  final _notes = TextEditingController();
  String _account = 'Transfer';
  List<Map<String, dynamic>> _cats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && (args == 'income' || args == 'expense')) {
        setState(() {
          _type = args;
        });
      }
      _loadCats();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      final rows = await context.read<AppDatabase>().getCategories(_type);
      if (!mounted) return;
      setState(() {
        _cats = rows;
        if (_cats.isEmpty) {
          _categoryId = null;
        } else {
          final has = _cats.any((e) => e['id'] == _categoryId);
          if (!has) _categoryId = _cats.first['id'] as int;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cats = []);
    }
  }

  Future<void> _save() async {
    final amount = num.tryParse(
      _amount.text.replaceAll('.', '').replaceAll(',', '.'),
    )?.toDouble();
    if (amount == null || _categoryId == null) {
      showErrorSnackbar(context, 'Lengkapi jumlah dan kategori dulu.');
      return;
    }
    await context.read<AppDatabase>().insertTransaction({
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'type': _type,
      'category_id': _categoryId,
      'amount': amount,
      'source_or_payee': _payee.text,
      'account': _account,
      'notes': _notes.text,
    });
    if (!mounted) return;

    await _showEditorialSuccess();

    if (!mounted) return;
    setState(() {
      _amount.clear();
      _payee.clear();
      _notes.clear();
      _date = DateTime.now();
    });

    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showEditorialSuccess() async {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final paper = ThemeUtils.getBackgroundColor(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        elevation: 0,
        backgroundColor: paper,
        insetPadding: const EdgeInsets.all(AppTheme.space24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          side: BorderSide(
            color: ThemeUtils.isDarkMode(dialogContext)
                ? AppTheme.darkHairlineColor
                : AppTheme.hairlineColor,
            width: AppTheme.hairlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space24,
            AppTheme.space32,
            AppTheme.space24,
            AppTheme.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AccentBar(
                    width: 24,
                    height: 2,
                    color: ThemeUtils.getPrimaryColor(dialogContext),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  const Eyebrow('TERBIT'),
                ],
              ),
              const SizedBox(height: AppTheme.space20),
              Text(
                'Catatan tersimpan.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -0.6,
                  color: ink,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                'Halaman keuanganmu sudah diperbarui dan siap dibaca.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: secondary,
                ),
              ),
              const SizedBox(height: AppTheme.space24),
              const Hairline(),
              const SizedBox(height: AppTheme.space16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('SELESAI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final isExpense = _type == 'expense';
    final amountColor = isExpense
        ? ThemeUtils.getExpenseColor(context)
        : ThemeUtils.getIncomeColor(context);

    final content = Column(
      children: [
        const SizedBox(height: AppTheme.space8),

        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pageGutter,
              AppTheme.space8,
              AppTheme.pageGutter,
              widget.isModal
                  ? AppTheme.space24
                  : MediaQuery.of(context).viewInsets.bottom + AppTheme.space24,
            ),
            children: [
              // Type segmented (underline style)
              _buildTypeSegment(ink, secondary, amountColor),
              const SizedBox(height: AppTheme.space32),

              // Display amount
              Eyebrow(
                isExpense ? 'JUMLAH PENGELUARAN' : 'JUMLAH PEMASUKAN',
                color: amountColor,
                size: 11,
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: secondary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 44,
                        fontWeight: FontWeight.w600,
                        color: amountColor,
                        letterSpacing: -1.2,
                        height: 1.0,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: '0',
                        hintStyle: GoogleFonts.spaceGrotesk(
                          fontSize: 44,
                          fontWeight: FontWeight.w600,
                          color: secondary.withOpacity(0.4),
                          letterSpacing: -1.2,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Container(height: 2, color: amountColor),

              const SizedBox(height: AppTheme.space32),

              // Field rows — hairline-divided
              _buildFieldRow(
                label: 'KATEGORI',
                child: _buildCategoryDropdown(),
              ),
              _buildFieldRow(
                label: 'TANGGAL',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('dd MMMM yyyy', 'id').format(_date),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: ink,
                          ),
                        ),
                      ),
                      Icon(Icons.calendar_today, size: 16, color: secondary),
                    ],
                  ),
                ),
              ),
              _buildFieldRow(label: 'METODE', child: _buildAccountDropdown()),
              _buildFieldRow(
                label: 'KETERANGAN',
                child: TextField(
                  controller: _payee,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Misal: Belanja bulanan',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondary,
                    ),
                  ),
                ),
              ),
              _buildFieldRow(
                label: 'CATATAN',
                isLast: true,
                child: TextField(
                  controller: _notes,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: ink,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Tulis catatan tambahan…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom CTA
        Container(
          decoration: BoxDecoration(
            color: paper,
            border: Border(
              top: BorderSide(
                color: ThemeUtils.isDarkMode(context)
                    ? AppTheme.darkHairlineColor
                    : AppTheme.hairlineColor,
                width: AppTheme.hairlineWidth,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space16,
            AppTheme.pageGutter,
            MediaQuery.of(context).padding.bottom + AppTheme.space16,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: const Text('SIMPAN'),
            ),
          ),
        ),
      ],
    );

    if (widget.isModal) {
      return Material(
        color: paper,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSmall),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeUtils.isDarkMode(context)
                        ? AppTheme.darkHairlineColor
                        : AppTheme.hairlineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(child: content),
    );
  }

  Widget _buildTypeSegment(Color ink, Color secondary, Color amountColor) {
    final accent = ThemeUtils.getPrimaryColor(context);
    final segments = const [
      ('expense', 'PENGELUARAN'),
      ('income', 'PEMASUKAN'),
    ];

    return Column(
      children: [
        Row(
          children: segments.map((s) {
            final selected = _type == s.$1;
            final color = s.$1 == 'expense'
                ? ThemeUtils.getExpenseColor(context)
                : ThemeUtils.getIncomeColor(context);
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_type != s.$1) {
                    setState(() {
                      _type = s.$1;
                      _categoryId = null;
                    });
                    _loadCats();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? (selected && _type == s.$1 ? color : accent)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      s.$2,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: selected ? color : secondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    if (_cats.isEmpty) {
      return Text(
        'Belum ada kategori untuk tipe ini.',
        style: GoogleFonts.inter(fontSize: 13, color: secondary),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _cats.any((e) => e['id'] == _categoryId) ? _categoryId : null,
        isExpanded: true,
        icon: Icon(Icons.expand_more, color: secondary),
        hint: Text(
          'Pilih kategori',
          style: GoogleFonts.inter(fontSize: 14, color: secondary),
        ),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        items: [
          for (final c in _cats)
            DropdownMenuItem(
              value: c['id'] as int,
              child: Row(
                children: [
                  Text(
                    c['emoji'] as String? ?? '•',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    c['name'] as String,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (v) => setState(() => _categoryId = v),
      ),
    );
  }

  Widget _buildAccountDropdown() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _account,
        isExpanded: true,
        icon: Icon(Icons.expand_more, color: secondary),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        items: const [
          DropdownMenuItem(value: 'Transfer', child: Text('Bank / Transfer')),
          DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
          DropdownMenuItem(value: 'E-Wallet', child: Text('E-Wallet')),
        ],
        onChanged: (v) => setState(() => _account = v ?? _account),
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required Widget child,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space20),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: ThemeUtils.isDarkMode(context)
                      ? AppTheme.darkHairlineColor
                      : AppTheme.hairlineColor,
                  width: AppTheme.hairlineWidth,
                ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Eyebrow(label),
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(child: child),
        ],
      ),
    );
  }
}
