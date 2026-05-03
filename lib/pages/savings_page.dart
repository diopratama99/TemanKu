import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  List<Map<String, dynamic>> _goals = [];
  bool _loading = false;
  double _totalTarget = 0;
  double _totalSaved = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final rows = await db.getSavingsGoals();

    double totalTarget = 0;
    double totalSaved = 0;
    for (final row in rows) {
      if (row['archived_at'] == null) {
        totalTarget += (row['target_amount'] as num).toDouble();
        totalSaved += (row['allocated'] as num).toDouble();
      }
    }

    setState(() {
      _goals = rows;
      _totalTarget = totalTarget;
      _totalSaved = totalSaved;
      _loading = false;
    });
  }

  String _money(num v) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final activeGoals = _goals.where((e) => e['archived_at'] == null).toList();
    final archivedGoals = _goals
        .where((e) => e['archived_at'] != null)
        .toList();
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: _loading
            ? const LoadingStateWidget(message: 'Memuat tabungan...')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EditorialHeader(
                    eyebrow: 'TABUNGAN',
                    title: 'Target.',
                    metaEyebrow: 'AKTIF',
                    meta: '${activeGoals.length} target',
                    titleSize: 36,
                    showBackButton: true,
                  ),
                  if (activeGoals.isNotEmpty) _buildEditorialSummary(),
                  Expanded(
                    child: activeGoals.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.savings_outlined,
                            title: 'Belum ada target tabungan',
                            description:
                                'Buat target tabungan untuk mencapai tujuan finansial Anda.',
                            actionLabel: 'Buat Target',
                            onAction: _showAddGoalDialog,
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (final goal in activeGoals)
                                _GoalRow(
                                  goal: goal,
                                  money: _money,
                                  onTap: () => _showGoalDetails(goal),
                                  onAddAllocation: () =>
                                      _showAddAllocationDialog(goal),
                                  onEdit: () => _showEditGoalDialog(goal),
                                  onArchive: () => _archiveGoal(goal),
                                  onDelete: () => _deleteGoal(goal),
                                ),
                              if (archivedGoals.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.space16),
                                EditorialSectionHeader(
                                  eyebrow: 'ARSIP',
                                  title: '${archivedGoals.length} target lama',
                                ),
                                for (final goal in archivedGoals)
                                  _GoalRow(
                                    goal: goal,
                                    isArchived: true,
                                    money: _money,
                                    onTap: () => _showGoalDetails(goal),
                                    onUnarchive: () => _unarchiveGoal(goal),
                                    onDelete: () => _deleteGoal(goal),
                                  ),
                              ],
                              const SizedBox(height: AppTheme.space24),
                            ],
                          ),
                  ),
                  const Hairline(),
                  Material(
                    color: paper,
                    child: InkWell(
                      onTap: _showAddGoalDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.pageGutter,
                          vertical: AppTheme.space20,
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            Text(
                              'Target tabungan baru',
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

  Widget _buildEditorialSummary() {
    final percentage = _totalTarget > 0
        ? (_totalSaved / _totalTarget * 100)
        : 0.0;
    final remaining = _totalTarget - _totalSaved;
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isDark = ThemeUtils.isDarkMode(context);

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
          Eyebrow('TERKUMPUL', color: secondary),
          const SizedBox(height: AppTheme.space8),
          Text(
            _money(_totalSaved),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.0,
              height: 1.05,
              color: ink,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'dari ${_money(_totalTarget)}',
            style: GoogleFonts.inter(fontSize: 13, color: secondary),
          ),
          const SizedBox(height: AppTheme.space20),
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
              child: Container(color: accent),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}% dari target',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                remaining > 0 ? 'Sisa ${_money(remaining)}' : 'Tercapai',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddGoalDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Target Tabungan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Target',
                  hintText: 'Contoh: Liburan ke Bali',
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
                  labelText: 'Target Jumlah',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                  helperText: 'Jumlah yang ingin dicapai',
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
              if (nameCtrl.text.trim().isEmpty) {
                showErrorSnackbar(context, 'Nama target harus diisi');
                return;
              }

              final target = num.tryParse(
                amountCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
              )?.toDouble();

              if (target == null || target <= 0) {
                showErrorSnackbar(context, 'Target jumlah harus lebih dari 0');
                return;
              }

              await context.read<AppDatabase>().insertSavingsGoal({
                'name': nameCtrl.text.trim(),
                'target_amount': target,
              });

              if (!mounted) return;
              Navigator.pop(context);
              showSuccessSnackbar(context, 'Target berhasil dibuat');
              await _load();
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

  Future<void> _showGoalDetails(Map<String, dynamic> goal) async {
    // Show allocations history
    final goalId = goal['id'] as int;
    final allocations = await context
        .read<AppDatabase>()
        .client
        .from('savings_allocations')
        .select()
        .eq('goal_id', goalId)
        .order('date', ascending: false);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Riwayat Alokasi',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Allocations List
            Expanded(
              child: allocations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada riwayat',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: allocations.length,
                      itemBuilder: (context, i) {
                        final alloc = allocations[i];
                        final amount = (alloc['amount'] as num).toDouble();
                        final isPositive = amount >= 0;
                        final date = DateTime.parse(alloc['date'] as String);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      (isPositive ? Colors.green : Colors.red)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPositive ? Icons.add : Icons.remove,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _money(amount.abs()),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                        'id_ID',
                                      ).format(date),
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }

  Future<void> _showAddAllocationDialog(Map<String, dynamic> goal) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah ke ${goal['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
              decoration: InputDecoration(
                labelText: 'Jumlah',
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor.withOpacity(0.6),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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

              if (amount == null || amount <= 0) {
                showErrorSnackbar(context, 'Jumlah harus lebih dari 0');
                return;
              }

              await context.read<AppDatabase>().insertSavingsAllocation({
                'goal_id': goal['id'],
                'amount': amount,
                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'note': noteCtrl.text.trim(),
              });

              if (!mounted) return;
              Navigator.pop(context);
              showSuccessSnackbar(context, 'Alokasi berhasil ditambahkan');
              await _load();
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

  Future<void> _showEditGoalDialog(Map<String, dynamic> goal) async {
    final nameCtrl = TextEditingController(text: goal['name'] as String);
    final amountCtrl = TextEditingController(
      text: (goal['target_amount'] as num).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Target',
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
                labelText: 'Target Jumlah',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
              final target = num.tryParse(
                amountCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
              )?.toDouble();

              if (nameCtrl.text.trim().isEmpty ||
                  target == null ||
                  target <= 0) {
                showErrorSnackbar(context, 'Data tidak valid');
                return;
              }

              await context.read<AppDatabase>().updateSavingsGoal(
                goal['id'] as int,
                {'name': nameCtrl.text.trim(), 'target_amount': target},
              );

              if (!mounted) return;
              Navigator.pop(context);
              showSuccessSnackbar(context, 'Target berhasil diperbarui');
              await _load();
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

  Future<void> _archiveGoal(Map<String, dynamic> goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan Target'),
        content: Text('Arsipkan "${goal['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AppDatabase>().updateSavingsGoal(goal['id'] as int, {
        'archived_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      showSuccessSnackbar(context, 'Target berhasil diarsipkan');
      await _load();
    }
  }

  Future<void> _unarchiveGoal(Map<String, dynamic> goal) async {
    await context.read<AppDatabase>().updateSavingsGoal(goal['id'] as int, {
      'archived_at': null,
    });
    if (!mounted) return;
    showSuccessSnackbar(context, 'Target dikembalikan dari arsip');
    await _load();
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Target'),
        content: Text(
          'Hapus "${goal['name']}"? Semua riwayat alokasi akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentGreen,
            ),
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
      await context.read<AppDatabase>().deleteSavingsGoal(goal['id'] as int);
      if (!mounted) return;
      showSuccessSnackbar(context, 'Target berhasil dihapus');
      await _load();
    }
  }
}

class _GoalRow extends StatelessWidget {
  final Map<String, dynamic> goal;
  final bool isArchived;
  final String Function(num) money;
  final VoidCallback onTap;
  final VoidCallback? onAddAllocation;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback onDelete;

  const _GoalRow({
    required this.goal,
    this.isArchived = false,
    required this.money,
    required this.onTap,
    this.onAddAllocation,
    this.onEdit,
    this.onArchive,
    this.onUnarchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final target = (goal['target_amount'] as num).toDouble();
    final saved = (goal['allocated'] as num).toDouble();
    final percentage = target > 0 ? (saved / target * 100) : 0.0;
    final remaining = target - saved;
    final isCompleted = percentage >= 100;
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final income = ThemeUtils.getIncomeColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairline = isDark
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;
    final progressColor = isArchived
        ? secondary
        : (isCompleted ? income : accent);
    final statusEyebrow = isArchived
        ? 'ARSIP'
        : (isCompleted ? 'TERCAPAI' : '${percentage.toStringAsFixed(0)}%');
    final statusColor = isArchived
        ? secondary
        : (isCompleted ? income : secondary);

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
                            Eyebrow(statusEyebrow, color: statusColor),
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              goal['name'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                                color: isArchived ? secondary : ink,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      if (!isArchived)
                        IconButton(
                          onPressed: onAddAllocation,
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: 22,
                            color: accent,
                          ),
                          tooltip: 'Tambah alokasi',
                          visualDensity: VisualDensity.compact,
                        ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, color: secondary),
                        offset: const Offset(0, 36),
                        onSelected: (value) {
                          if (value == 'edit') onEdit?.call();
                          if (value == 'archive') onArchive?.call();
                          if (value == 'unarchive') onUnarchive?.call();
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (context) => [
                          if (!isArchived)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                          if (!isArchived)
                            const PopupMenuItem(
                              value: 'archive',
                              child: Text('Arsipkan'),
                            ),
                          if (isArchived)
                            const PopupMenuItem(
                              value: 'unarchive',
                              child: Text('Kembalikan'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Hapus'),
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
                          Eyebrow('TERKUMPUL', color: secondary, size: 10),
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            money(saved),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                              color: isArchived ? secondary : ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppTheme.space20),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ ${money(target)}',
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
                  if (!isCompleted && !isArchived) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Sisa ${money(remaining.clamp(0, double.infinity))}',
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
