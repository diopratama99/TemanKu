import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

class AccountTransfersPage extends StatefulWidget {
  const AccountTransfersPage({super.key});

  @override
  State<AccountTransfersPage> createState() => _AccountTransfersPageState();
}

class _AccountTransfersPageState extends State<AccountTransfersPage> {
  late String _month; // YYYY-MM
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _balances = [];
  bool _loading = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _month = DateFormat('yyyy-MM').format(DateTime.now());
    _load();
  }

  String _money(num v) => 'Rp ${NumberFormat.decimalPattern('id').format(v)}';

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final allTransfers = await db.getAccountTransfers();
    final rows = allTransfers.where((r) {
      final d = r['date'] as String;
      return d.startsWith(_month);
    }).toList();
    final balances = await db.accountBalancesByMonth(_month);
    setState(() {
      _rows = rows;
      _balances = balances;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: _loading
            ? const LoadingStateWidget(message: 'Memuat saldo...')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EditorialHeader(
                    eyebrow: 'AKUN',
                    title: 'Saldo.',
                    metaEyebrow: 'BULAN',
                    meta: _monthLabel(),
                    titleSize: 36,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Account balances
                        if (_balances.isNotEmpty) ...[
                          for (final balance in _balances)
                            _AccountBalanceRow(
                              label: balance['label'] as String,
                              account: balance['acc'] as String,
                              saldo: (balance['saldo'] as num).toDouble(),
                              money: _money,
                              icon: _iconFor(balance['acc'] as String),
                            ),
                        ] else ...[
                          const Hairline(),
                          Padding(
                            padding: const EdgeInsets.all(AppTheme.space24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow('KOSONG', color: secondary),
                                const SizedBox(height: AppTheme.space8),
                                Text(
                                  'Belum ada saldo akun.',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.4,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Hairline(),

                        // History toggle
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _showHistory = !_showHistory),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.pageGutter,
                                vertical: AppTheme.space20,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Eyebrow('RIWAYAT', color: secondary),
                                        const SizedBox(height: AppTheme.space4),
                                        Text(
                                          _rows.isEmpty
                                              ? 'Belum ada mutasi'
                                              : '${_rows.length} mutasi bulan ini',
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
                                  Icon(
                                    _showHistory
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: secondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_showHistory) ...[
                          for (int i = 0; i < _rows.length; i++)
                            _TransferHistoryRow(
                              row: _rows[i],
                              money: _money,
                              onDelete: () async {
                                await context.read<AppDatabase>().deleteAccountTransfer(
                                  _rows[i]['id'] as int,
                                );
                                _rows.removeAt(i);
                                if (mounted) setState(() {});
                              },
                            ),
                        ],
                        const SizedBox(height: AppTheme.space24),
                      ],
                    ),
                  ),

                  // Bottom add bar
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
                            AccentBar(
                              width: 24,
                              height: 2,
                              color: ThemeUtils.getPrimaryColor(context),
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Eyebrow('TAMBAH', color: secondary),
                            const Spacer(),
                            Text(
                              'Mutasi antar akun',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Icon(Icons.swap_horiz, size: 22, color: ink),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    DateTime date = DateTime.now();
    String from = 'Transfer';
    String to = 'Tunai';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final feeCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).canvasColor,
      useSafeArea: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Tambah Mutasi Akun',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: from,
                        items: const [
                          DropdownMenuItem(
                            value: 'Transfer',
                            child: Text('Rekening'),
                          ),
                          DropdownMenuItem(
                            value: 'Tunai',
                            child: Text('Tunai'),
                          ),
                          DropdownMenuItem(
                            value: 'E-Wallet',
                            child: Text('E-Wallet'),
                          ),
                        ],
                        onChanged: (v) => from = v ?? 'Transfer',
                        decoration: const InputDecoration(labelText: 'Dari'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: to,
                        items: const [
                          DropdownMenuItem(
                            value: 'Transfer',
                            child: Text('Rekening'),
                          ),
                          DropdownMenuItem(
                            value: 'Tunai',
                            child: Text('Tunai'),
                          ),
                          DropdownMenuItem(
                            value: 'E-Wallet',
                            child: Text('E-Wallet'),
                          ),
                        ],
                        onChanged: (v) => to = v ?? 'Tunai',
                        decoration: const InputDecoration(labelText: 'Ke'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    prefixText: 'Rp ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: feeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Biaya admin (opsional)',
                    prefixText: 'Rp ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) date = picked;
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('yyyy-MM-dd').format(date)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final amount = _parseAmount(amountCtrl.text);
                          final fee = _parseAmount(feeCtrl.text) ?? 0.0;
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Jumlah tidak valid'),
                              ),
                            );
                            return;
                          }
                          if (from == to) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pilih akun yang berbeda'),
                              ),
                            );
                            return;
                          }
                          await context
                              .read<AppDatabase>()
                              .insertAccountTransferWithFee(
                                dateIso: DateFormat('yyyy-MM-dd').format(date),
                                fromAccount: from,
                                toAccount: to,
                                amount: amount,
                                note: noteCtrl.text,
                                adminFee: fee,
                              );
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mutasi disimpan')),
                          );
                          await _load();
                        },
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _monthLabel() {
    try {
      final dt = DateTime.parse('$_month-01');
      final m = DateFormat('MMMM', 'id').format(dt);
      final y = DateFormat('y').format(dt);
      return '$m - $y';
    } catch (_) {
      return _month;
    }
  }

  double? _parseAmount(String raw) {
    final s = raw
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(s);
  }

  IconData _iconFor(String acc) {
    switch (acc) {
      case 'Transfer':
        return Icons.account_balance;
      case 'Tunai':
        return Icons.payments_outlined;
      case 'E-Wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _AccountBalanceRow extends StatelessWidget {
  final String label;
  final String account;
  final double saldo;
  final String Function(num) money;
  final IconData icon;

  const _AccountBalanceRow({
    required this.label,
    required this.account,
    required this.saldo,
    required this.money,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final isNegative = saldo < 0;
    final amountColor = isNegative ? expense : ink;

    return Column(
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pageGutter,
            vertical: AppTheme.space20,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: ink),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(account.toUpperCase(), color: secondary),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                money(saldo),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferHistoryRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final String Function(num) money;
  final Future<void> Function() onDelete;

  const _TransferHistoryRow({
    required this.row,
    required this.money,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Dismissible(
      key: ValueKey(row['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: ThemeUtils.getExpenseColor(context),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.pageGutter),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Column(
        children: [
          const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
              vertical: AppTheme.space20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        '${row['from_account']} → ${row['to_account']}',
                        color: secondary,
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        row['date'] as String? ?? '-',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: ink,
                        ),
                      ),
                      if (((row['note'] as String?) ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          row['note'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Text(
                  money(row['amount'] as num),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
