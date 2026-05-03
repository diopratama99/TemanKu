import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/editorial.dart';
import '../utils/theme_utils.dart';
import 'package:intl/intl.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  final db = AppDatabase();
  bool _isLoading = true;
  List<Map<String, dynamic>> _debts = [];
  String _activeTab = 'payable'; // 'payable' = Hutang, 'receivable' = Piutang
  String _statusFilter = 'active'; // 'active' or 'paid'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await db.getDebts();
    if (!mounted) return;
    setState(() {
      _debts = data;
      _isLoading = false;
    });
  }

  Future<void> _markAsPaid(int id) async {
    await db.updateDebt(id, {'status': 'paid'});
    _load();
  }
  
  Future<void> _deleteDebt(int id) async {
    await db.deleteDebt(id);
    _load();
  }

  void _showAddDebtDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddDebtForm(
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _showEditDebtDialog(Map<String, dynamic> debt) {
    showDialog(
      context: context,
      builder: (ctx) => _AddDebtForm(
        initialDebt: debt,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _showAddPaymentDialog(Map<String, dynamic> debt) {
    showDialog(
      context: context,
      builder: (ctx) => _AddPaymentForm(
        debt: debt,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _showDebtDetails(Map<String, dynamic> debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DebtDetailsSheet(
        debt: debt,
        onPaymentAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairlineColor = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;
    
    final displayedDebts = _debts.where((d) => d['type'] == _activeTab && d['status'] == _statusFilter).toList();

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            EditorialHeader(
              eyebrow: 'MANAJEMEN',
              title: 'Hutang &\nPiutang.',
              showBackButton: true,
              metaEyebrow: _activeTab == 'payable' ? 'HUTANG' : 'PIUTANG',
              meta: '${displayedDebts.length} data',
            ),
            
            // Tabs Row 1
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
              child: Row(
                children: [
                  _CustomTab(
                    label: 'HUTANG',
                    isSelected: _activeTab == 'payable',
                    onTap: () {
                      setState(() {
                        _activeTab = 'payable';
                        _statusFilter = 'active';
                      });
                    },
                  ),
                  _CustomTab(
                    label: 'PIUTANG',
                    isSelected: _activeTab == 'receivable',
                    onTap: () {
                      setState(() {
                        _activeTab = 'receivable';
                        _statusFilter = 'active';
                      });
                    },
                  ),
                ],
              ),
            ),
            const Hairline(),
            
            // Tabs Row 2
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
              child: Row(
                children: [
                  _CustomTab(
                    label: 'AKTIF',
                    isSelected: _statusFilter == 'active',
                    onTap: () => setState(() => _statusFilter = 'active'),
                  ),
                  _CustomTab(
                    label: 'SELESAI',
                    isSelected: _statusFilter == 'paid',
                    onTap: () => setState(() => _statusFilter = 'paid'),
                  ),
                ],
              ),
            ),
            const Hairline(),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayedDebts.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada data',
                            style: GoogleFonts.inter(color: secondary),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: displayedDebts.length,
                          itemBuilder: (ctx, idx) {
                            final d = displayedDebts[idx];
                            return _DebtCard(
                              debt: d,
                              onTap: () => _showDebtDetails(d),
                              onAddPayment: () => _showAddPaymentDialog(d),
                              onEdit: () => _showEditDebtDialog(d),
                              onMarkPaid: () => _markAsPaid(d['id']),
                              onDelete: () => _deleteDebt(d['id']),
                            );
                          },
                        ),
            ),
            
            const Hairline(),
            Material(
              color: paper,
              child: InkWell(
                onTap: _showAddDebtDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pageGutter,
                    vertical: AppTheme.space20,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      Text(
                        'Catat hutang baru',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Icon(Icons.add, size: 20, color: ink),
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
}

class _DebtCard extends StatelessWidget {
  final Map<String, dynamic> debt;
  final VoidCallback onTap;
  final VoidCallback onAddPayment;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _DebtCard({
    required this.debt,
    required this.onTap,
    required this.onAddPayment,
    required this.onEdit,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final target = (debt['amount'] as num).toDouble();
    final saved = (debt['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final percentage = target > 0 ? (saved / target * 100) : 0.0;
    final remaining = target - saved;
    final isCompleted = percentage >= 100 || debt['status'] == 'paid';
    
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final isPayable = debt['type'] == 'payable';
    
    final accent = ThemeUtils.getPrimaryColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairline = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;
    final progressColor = isCompleted ? ThemeUtils.getIncomeColor(context) : accent;

    final statusText = isCompleted ? 'LUNAS' : (isPayable ? 'HUTANG' : 'PIUTANG');
    final statusColor = isCompleted ? ThemeUtils.getIncomeColor(context) : (isPayable ? ThemeUtils.getExpenseColor(context) : ThemeUtils.getIncomeColor(context));

    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(statusText, color: statusColor),
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              debt['name'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                                color: isCompleted ? secondary : ink,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      if (!isCompleted)
                        IconButton(
                          onPressed: onAddPayment,
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: 22,
                            color: accent,
                          ),
                          tooltip: 'Catat cicilan',
                          visualDensity: VisualDensity.compact,
                        ),
                      if (!isCompleted)
                        IconButton(
                          onPressed: onMarkPaid,
                          icon: Icon(
                            Icons.check_circle_outline,
                            size: 22,
                            color: ThemeUtils.getPrimaryColor(context),
                          ),
                          tooltip: 'Tandai lunas',
                          visualDensity: VisualDensity.compact,
                        ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, size: 20, color: secondary),
                        padding: EdgeInsets.zero,
                        tooltip: 'Opsi lainnya',
                        onSelected: (val) {
                          if (val == 'edit') onEdit();
                          if (val == 'delete') onDelete();
                        },
                        itemBuilder: (ctx) => [
                          if (!isCompleted)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Hapus',
                              style: GoogleFonts.inter(
                                color: ThemeUtils.getExpenseColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space12),
                  // Saved / target row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow('TERBAYAR', color: secondary, size: 10),
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            formatter.format(saved),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                              color: isCompleted ? secondary : ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppTheme.space20),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ ${formatter.format(target)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
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
                  if (debt['notes']?.isNotEmpty == true) ...[
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      debt['notes'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ink,
                      ),
                    ),
                  ],
                  if (!isCompleted) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Sisa ${formatter.format(remaining.clamp(0, double.infinity))}',
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

class _CustomTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final green = ThemeUtils.getAccentGreen(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: isSelected ? ink : secondary,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Container(
                height: 2,
                color: isSelected ? green : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDebtForm extends StatefulWidget {
  final Map<String, dynamic>? initialDebt;
  final VoidCallback onSaved;
  const _AddDebtForm({this.initialDebt, required this.onSaved});

  @override
  State<_AddDebtForm> createState() => _AddDebtFormState();
}

class _AddDebtFormState extends State<_AddDebtForm> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'payable';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDebt != null) {
      final d = widget.initialDebt!;
      _nameCtrl.text = d['name'];
      _amountCtrl.text = d['amount'].toString();
      _notesCtrl.text = d['notes'] ?? '';
      _type = d['type'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairlineColor = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;

    return AlertDialog(
      title: const Text('Tambah Catatan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'payable', label: Text('Hutang')),
                ButtonSegment(value: 'receivable', label: Text('Piutang')),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.transparent,
                selectedBackgroundColor: AppTheme.accentGreen.withOpacity(0.1),
                foregroundColor: secondary,
                selectedForegroundColor: AppTheme.accentGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: secondary.withOpacity(0.2)),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Orang/Instansi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jumlah Nominal',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                border: OutlineInputBorder(),
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
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentGreen,
          ),
          child: _saving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    final amountText = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountText) ?? 0.0;
    
    if (name.isEmpty || amount <= 0) return;
    
    setState(() => _saving = true);
    
    final data = {
      'name': name,
      'amount': amount,
      'type': _type,
      'notes': _notesCtrl.text.trim(),
    };

    if (widget.initialDebt != null) {
      await context.read<AppDatabase>().updateDebt(widget.initialDebt!['id'], data);
    } else {
      await context.read<AppDatabase>().insertDebt(data);
    }
    
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }
}

class _AddPaymentForm extends StatefulWidget {
  final Map<String, dynamic> debt;
  final VoidCallback onSaved;

  const _AddPaymentForm({required this.debt, required this.onSaved});

  @override
  State<_AddPaymentForm> createState() => _AddPaymentFormState();
}

class _AddPaymentFormState extends State<_AddPaymentForm> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Catat Cicilan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jumlah Cicilan',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                border: OutlineInputBorder(),
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
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentGreen,
          ),
          child: _saving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() async {
    final amountText = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountText) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _saving = true);

    await context.read<AppDatabase>().insertDebtPayment({
      'debt_id': widget.debt['id'],
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'note': _noteCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }
}

class _DebtDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> debt;
  final VoidCallback onPaymentAdded;

  const _DebtDetailsSheet({required this.debt, required this.onPaymentAdded});

  @override
  State<_DebtDetailsSheet> createState() => _DebtDetailsSheetState();
}

class _DebtDetailsSheetState extends State<_DebtDetailsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final res = await db.client
        .from('debt_payments')
        .select()
        .eq('debt_id', widget.debt['id'])
        .order('created_at', ascending: false);
    
    if (!mounted) return;
    setState(() {
      _payments = res.cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairlineColor = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;
    
    final target = (widget.debt['amount'] as num).toDouble();
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.space12),
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: secondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('RIWAYAT PEMBAYARAN', color: secondary),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        widget.debt['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: ink,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatter.format(target),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          Container(height: 1, color: hairlineColor),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: ThemeUtils.getPrimaryColor(context),
                    ),
                  )
                : _payments.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada pembayaran',
                          style: GoogleFonts.inter(color: secondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => Container(height: 1, color: hairlineColor),
                        itemBuilder: (ctx, idx) {
                          final p = _payments[idx];
                          final note = p['note'] as String?;
                          return Padding(
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
                                      Text(
                                        p['date'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: ink,
                                        ),
                                      ),
                                      if (note != null && note.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          note,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: secondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  formatter.format(p['amount']),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: ink,
                                  ),
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
