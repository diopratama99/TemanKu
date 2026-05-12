import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  late String _month; // YYYY-MM
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _expCats = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateFormat('yyyy-MM').format(now);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = context.read<AppDatabase>();
      final rows = await db.getBudgetsWithSpent(_month);
      final cats = await db.getCategories('expense');
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _expCats = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnackbar(context, 'Gagal memuat budget: $e');
    }
  }

  String _money(num v) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: _loading
            ? const LoadingStateWidget(message: 'Memuat budgeting...')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EditorialHeader(
                    eyebrow: 'BUDGET',
                    title: 'Anggaran.',
                    titleSize: 36,
                  ),
                  if (_rows.isNotEmpty) _buildEditorialSummary(),
                  Expanded(
                    child: _rows.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.pie_chart_outline,
                            title: 'Belum ada budget',
                            description:
                                'Atur budget pengeluaranmu untuk kontrol keuangan yang lebih baik.',
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _rows.length + 1,
                            itemBuilder: (context, i) {
                              if (i == _rows.length) {
                                return const SizedBox(height: AppTheme.space24);
                              }
                              final r = _rows[i];
                              return _BudgetRow(
                                budget: r,
                                money: _money,
                                onTap: () => _showEditDialog(r),
                                onDelete: () => _deleteBudget(r),
                              );
                            },
                          ),
                  ),
                  // Bottom add bar
                  if (_rows.length < 5) ...[
                    const Hairline(),
                    Material(
                      color: paper,
                      child: InkWell(
                        onTap: _showAddDialog,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.pageGutter,
                            vertical: AppTheme.space20,
                          ),
                          child: Row(
                            children: [
                              const Spacer(),
                              Text(
                                'Tambah Budgeting',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeUtils.getTextPrimary(context),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: AppTheme.space12),
                              Icon(
                                Icons.add,
                                size: 20,
                                color: ThemeUtils.getTextPrimary(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEditorialSummary() {
    double totalBudget = 0;
    double totalSpent = 0;
    for (final r in _rows) {
      totalBudget += (r['amount'] as num).toDouble();
      totalSpent += (r['spent'] as num).toDouble();
    }
    final percentage = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;
    final remaining = totalBudget - totalSpent;
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final overBudget = percentage > 100;
    final amountColor = overBudget
        ? (isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor)
        : ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageGutter,
        AppTheme.space24,
        AppTheme.pageGutter,
        AppTheme.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two-column row: Anggaran kiri, Terpakai kanan
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('ANGGARAN', color: secondary),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        _money(totalBudget),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: ink,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalHairline(),
                const SizedBox(width: AppTheme.space20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Eyebrow('TERPAKAI', color: secondary),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        _money(totalSpent),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: amountColor,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space20),
          // Slim progress bar
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkHairlineColor
                  : AppTheme.hairlineColor,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percentage / 100).clamp(0.0, 1.0),
              child: Container(color: overBudget ? amountColor : accent),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}% terpakai',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                remaining >= 0
                    ? 'Sisa ${_money(remaining)}'
                    : 'Lebih ${_money(remaining.abs())}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: remaining >= 0 ? secondary : amountColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBudget(Map<String, dynamic> budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tabungan'),
        content: Text('Hapus target tabungan untuk ${budget['category']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AppDatabase>().deleteBudget(budget['id'] as int);
      if (!mounted) return;
      showSuccessSnackbar(context, 'Tabungan berhasil dihapus');
      await _load();
    }
  }

  Future<void> _showAddDialog() async {
    if (_rows.length >= 5) {
      showErrorSnackbar(context, 'Maksimal 5 budget per bulan');
      return;
    }

    int? selectedCatId;
    final amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Budget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedCatId,
                  items: [
                    for (final c in _expCats)
                      DropdownMenuItem(
                        value: c['id'] as int,
                        child: Row(
                          children: [
                            Text(
                              (c['emoji'] as String?) ?? '📁',
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Text(c['name'] as String),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedCatId = v),
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Budget',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                    helperText: 'Masukkan budget per bulan',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentGreen,
              ),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = num.tryParse(
                  amountCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
                )?.toDouble();

                if (selectedCatId == null) {
                  showErrorSnackbar(context, 'Pilih kategori terlebih dahulu');
                  return;
                }
                if (amount == null || amount <= 0) {
                  showErrorSnackbar(
                    context,
                    'Jumlah budget harus lebih dari 0',
                  );
                  return;
                }

                try {
                  await context.read<AppDatabase>().insertBudget({
                    'category_id': selectedCatId,
                    'month': _month,
                    'amount': amount,
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  showSuccessSnackbar(
                    context,
                    'Target tabungan berhasil ditambahkan',
                  );
                  await _load();
                } catch (e) {
                  if (!mounted) return;
                  showErrorSnackbar(
                    context,
                    'Gagal menambah target tabungan: $e',
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> budget) async {
    final amountCtrl = TextEditingController(
      text: (budget['amount'] as num).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tabungan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              budget['category'] as String,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Jumlah Target Tabungan',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentGreen),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = num.tryParse(
                amountCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
              )?.toDouble();

              if (amount == null || amount <= 0) {
                showErrorSnackbar(
                  context,
                  'Jumlah target tabungan harus lebih dari 0',
                );
                return;
              }

              try {
                await context.read<AppDatabase>().updateBudget(
                  budget['id'] as int,
                  {'amount': amount},
                );
                if (!mounted) return;
                Navigator.pop(context);
                showSuccessSnackbar(
                  context,
                  'Target tabungan berhasil diperbarui',
                );
                await _load();
              } catch (e) {
                if (!mounted) return;
                showErrorSnackbar(
                  context,
                  'Gagal memperbarui target tabungan: $e',
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final Map<String, dynamic> budget;
  final String Function(num) money;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BudgetRow({
    required this.budget,
    required this.money,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (budget['amount'] as num).toDouble();
    final spent = (budget['spent'] as num).toDouble();
    final percentage = amount > 0 ? (spent / amount * 100) : 0.0;
    final remaining = amount - spent;
    final emoji = budget['emoji'] as String? ?? '📊';
    final isOver = percentage > 100;
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairline = isDark
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;
    final amountColor = isOver ? expense : ink;
    final progressColor = isOver ? expense : accent;

    return Column(
      children: [
        const Hairline(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageGutter,
                AppTheme.space20,
                AppTheme.pageGutter,
                AppTheme.space20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(
                              isOver
                                  ? 'OVER ${percentage.toStringAsFixed(0)}%'
                                  : '${percentage.toStringAsFixed(0)}%',
                              color: isOver ? expense : secondary,
                            ),
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              budget['category'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Eyebrow('TERPAKAI', color: secondary, size: 10),
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            money(spent),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: amountColor,
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            'dari ${money(amount)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppTheme.space8),
                      InkWell(
                        onTap: onDelete,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(color: hairline),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (percentage / 100).clamp(0.0, 1.0),
                      child: Container(color: progressColor),
                    ),
                  ),
                  if (remaining < 0) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Lebih ${money(remaining.abs())}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: expense,
                      ),
                    ),
                  ] else if (remaining > 0) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Sisa ${money(remaining)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
