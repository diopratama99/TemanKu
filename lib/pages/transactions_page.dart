import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';
import 'add_transaction_page.dart';

class TransactionsPage extends StatefulWidget {
  final bool hideAddButton;

  const TransactionsPage({super.key, this.hideAddButton = false});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late DateTime _start;
  late DateTime _end;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final rows = await db.getTransactions(
      startDate: _iso(_start),
      endDate: _iso(_end),
    );
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final periodLabel =
        '${DateFormat('dd MMM', 'id_ID').format(_start)} – '
        '${DateFormat('dd MMM yyyy', 'id_ID').format(_end)}';

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const LoadingStateWidget(message: 'Mengumpulkan catatan...')
            : Column(
                children: [
                  EditorialHeader(
                    eyebrow: 'ARSIP',
                    title: 'Catatan',
                    titleSize: 36,
                    metaEyebrow: 'PERIODE',
                    meta: periodLabel,
                    showBackButton: true,
                  ),
                  // Period bar — hairline segment with INK button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.pageGutter,
                      vertical: AppTheme.space12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow(
                                'JUMLAH ENTRI',
                                color: secondary,
                                size: 10,
                              ),
                              const SizedBox(height: AppTheme.space4),
                              Text(
                                '${_rows.length} catatan',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showDateRangePicker,
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('UBAH PERIODE'),
                        ),
                      ],
                    ),
                  ),
                  const Hairline(),
                  Expanded(
                    child: _rows.isEmpty
                        ? EmptyStateWidget(
                            eyebrow: 'KOSONG',
                            icon: Icons.article_outlined,
                            title: 'Belum ada catatan',
                            description:
                                'Tidak ada transaksi pada rentang tanggal yang dipilih.',
                            actionLabel: 'Tulis transaksi',
                            onAction: () => _navigateToAdd(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.space80,
                            ),
                            itemCount: _rows.length,
                            itemBuilder: (context, i) {
                              final r = _rows[i];
                              return _ModernTransactionCard(
                                transaction: r,
                                onTap: () => _navigateToEdit(r),
                                onDelete: () => _deleteTransaction(r),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
      await _load();
    }
  }

  Future<void> _navigateToAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTransactionPage(showHistoryButton: false),
      ),
    );
    await _load();
  }

  Future<void> _navigateToEdit(Map<String, dynamic> transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTransactionPageModern(existing: transaction),
      ),
    );
    await _load();
  }

  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
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
      await context.read<AppDatabase>().deleteTransaction(
        transaction['id'] as int,
      );
      if (!mounted) return;
      showSuccessSnackbar(context, 'Transaksi berhasil dihapus');
      await _load();
    }
  }
}

class _ModernTransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ModernTransactionCard({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction['type'] == 'income';
    final amount = transaction['amount'] as num;
    final category = transaction['category'] as String? ?? 'Tanpa kategori';
    final emoji = transaction['category_emoji'] as String? ?? '•';
    final payee = (transaction['source_or_payee'] as String?) ?? '';
    final account = (transaction['account'] as String?) ?? '-';
    final date = DateFormat('yyyy-MM-dd').parse(transaction['date'] as String);
    final formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(date);
    final money = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final amountColor = isIncome
        ? ThemeUtils.getIncomeColor(context)
        : ThemeUtils.getExpenseColor(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    return Dismissible(
      key: Key('transaction_${transaction['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: ThemeUtils.getExpenseColor(context).withOpacity(0.08),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.pageGutter),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              color: ThemeUtils.getExpenseColor(context),
              size: 20,
            ),
            const SizedBox(width: AppTheme.space8),
            Text(
              'HAPUS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: ThemeUtils.getExpenseColor(context),
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: hairline,
                width: AppTheme.hairlineWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pageGutter,
            vertical: AppTheme.space20,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      isIncome
                          ? 'PEMASUKAN · $account'
                          : 'PENGELUARAN · $account',
                      color: amountColor,
                      size: 10,
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        height: 1.2,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      payee.isEmpty ? formattedDate : '$formattedDate · $payee',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.5,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Eyebrow(
                    isIncome ? 'MASUK' : 'KELUAR',
                    color: secondary,
                    size: 10,
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    '${isIncome ? '+' : '−'} ${money.format(amount)}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modern Edit Transaction Page
class EditTransactionPageModern extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const EditTransactionPageModern({super.key, this.existing});

  @override
  State<EditTransactionPageModern> createState() =>
      _EditTransactionPageModernState();
}

class _EditTransactionPageModernState extends State<EditTransactionPageModern> {
  late DateTime _date;
  late String _type;
  int? _categoryId;
  final _amount = TextEditingController();
  final _payee = TextEditingController();
  final _notes = TextEditingController();
  String _account = 'Transfer';
  List<Map<String, dynamic>> _cats = [];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _date = ex != null
        ? DateFormat('yyyy-MM-dd').parse(ex['date'] as String)
        : DateTime.now();
    _type = ex != null ? (ex['type'] as String) : 'expense';
    _account = ex != null
        ? ((ex['account'] as String?) ?? 'Transfer')
        : 'Transfer';
    _amount.text = ex != null ? ((ex['amount'] as num).toString()) : '';
    _payee.text = ex != null ? ((ex['source_or_payee'] as String?) ?? '') : '';
    _notes.text = ex != null ? ((ex['notes'] as String?) ?? '') : '';
    _categoryId = ex != null ? (ex['category_id'] as int?) : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      setState(() {
        _cats = [];
      });
    }
  }
  Future<void> _save() async {
    final amount = num.tryParse(
      _amount.text.replaceAll('.', '').replaceAll(',', '.'),
    )?.toDouble();

    if (amount == null || amount <= 0) {
      showErrorSnackbar(context, 'Jumlah harus lebih dari 0');
      return;
    }

    if (_categoryId == null) {
      showErrorSnackbar(context, 'Pilih kategori terlebih dahulu');
      return;
    }

    try {
      final data = {
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'type': _type,
        'category_id': _categoryId,
        'amount': amount,
        'source_or_payee': _payee.text,
        'account': _account,
        'notes': _notes.text,
      };
      if (widget.existing == null) {
        await context.read<AppDatabase>().insertTransaction(data);
      } else {
        await context.read<AppDatabase>().updateTransaction(
          widget.existing!['id'] as int,
          data,
        );
      }

      if (!mounted) return;
      showSuccessSnackbar(
        context,
        widget.existing == null
            ? 'Transaksi berhasil ditambahkan'
            : 'Transaksi berhasil diperbarui',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, 'Gagal menyimpan transaksi: $e');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
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

    if (confirm != true) return;

    try {
      await context.read<AppDatabase>().deleteTransaction(existing['id'] as int);
      if (!mounted) return;
      showSuccessSnackbar(context, 'Transaksi berhasil dihapus');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, 'Gagal menghapus transaksi: $e');
    }
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

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            EditorialHeader(
              eyebrow: 'SUNTING',
              title: widget.existing == null
                  ? 'Transaksi baru'
                  : 'Edit transaksi',
              titleSize: 36,
              showBackButton: true,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.pageGutter,
                  AppTheme.space8,
                  AppTheme.pageGutter,
                  MediaQuery.of(context).viewInsets.bottom + AppTheme.space24,
                ),
                children: [
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
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFieldRow(
                    label: 'METODE',
                    child: _buildAccountDropdown(),
                  ),
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
                height: 56,
                child: Row(
                  children: [
                    if (widget.existing != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.2),
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('HAPUS'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: ink),
                        child: const Text('SIMPAN'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                        color: selected ? color : accent.withOpacity(0),
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




