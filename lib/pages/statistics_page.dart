import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/descriptive_statistics.dart';
import '../utils/theme_utils.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/editorial.dart';

/// Modern Statistics Page - Financial Analytics & Insights
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  late DateTime _start;
  late DateTime _end;
  Map<String, dynamic>? _data;
  bool _loading = false;
  String _selectedPeriod = 'month'; // month, quarter, year

  late TabController _tabController;
  DescriptiveStatistics? _expenseStats;
  DescriptiveStatistics? _incomeStats;
  Map<String, double> _expenseCategoryData = {};
  Map<String, double> _incomeCategoryData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initPeriod();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'month':
        _start = DateTime(now.year, now.month, 1);
        _end = DateTime(now.year, now.month + 1, 0);
        break;
      case 'quarter':
        final quarter = ((now.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        _start = DateTime(now.year, startMonth, 1);
        _end = DateTime(now.year, startMonth + 3, 0);
        break;
      case 'year':
        _start = DateTime(now.year, 1, 1);
        _end = DateTime(now.year, 12, 31);
        break;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final auth = context.read<AuthNotifier>();
    final user = auth.user;

    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final data = await db.dashboardData(_iso(_start), _iso(_end));

    // Load transaction amounts for descriptive statistics
    final transactions = await _loadTransactionAmounts(db);

    // Load category data for donut chart
    final categoryData = await _loadCategoryData(db);

    // Load transaction counts
    final transactionCounts = await _loadTransactionCounts(db);
    data['transaction_counts'] = transactionCounts;

    setState(() {
      _data = data;
      _expenseStats = DescriptiveStatistics(transactions['expense'] ?? []);
      _incomeStats = DescriptiveStatistics(transactions['income'] ?? []);
      _expenseCategoryData = categoryData['expense'] ?? {};
      _incomeCategoryData = categoryData['income'] ?? {};
      _loading = false;
    });
  }

  Future<Map<String, int>> _loadTransactionCounts(AppDatabase db) async {
    final rows = await db.getTransactions(
      startDate: _iso(_start),
      endDate: _iso(_end),
    );

    int incomeCount = 0;
    int expenseCount = 0;
    for (final row in rows) {
      if (row['type'] == 'income') incomeCount++;
      else if (row['type'] == 'expense') expenseCount++;
    }
    return {'income': incomeCount, 'expense': expenseCount};
  }

  Future<Map<String, List<double>>> _loadTransactionAmounts(AppDatabase db) async {
    final rows = await db.getTransactions(
      startDate: _iso(_start),
      endDate: _iso(_end),
    );

    final expenseAmounts = <double>[];
    final incomeAmounts = <double>[];
    for (final row in rows) {
      final type = row['type'] as String?;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'expense') expenseAmounts.add(amount);
      else if (type == 'income') incomeAmounts.add(amount);
    }
    expenseAmounts.sort();
    incomeAmounts.sort();
    return {'expense': expenseAmounts, 'income': incomeAmounts};
  }

  Future<Map<String, Map<String, double>>> _loadCategoryData(AppDatabase db) async {
    final rows = await db.getTransactions(
      startDate: _iso(_start),
      endDate: _iso(_end),
    );

    final expenseData = <String, double>{};
    final incomeData = <String, double>{};
    for (final row in rows) {
      final type = row['type'] as String?;
      final category = (row['category'] as String?) ?? 'Lainnya';
      final emoji = (row['category_emoji'] as String?) ?? '📝';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final displayName = '$emoji $category';
      if (type == 'expense') {
        expenseData[displayName] = (expenseData[displayName] ?? 0) + amount;
      } else if (type == 'income') {
        incomeData[displayName] = (incomeData[displayName] ?? 0) + amount;
      }
    }
    return {'expense': expenseData, 'income': incomeData};
  }

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _money(num v) => 'Rp ${NumberFormat.decimalPattern('id').format(v)}';

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      _initPeriod();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: _loading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: accent,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EditorialHeader(
                    eyebrow: 'STATISTIK',
                    title: 'Analisa.',
                    titleSize: 36,
                    metaEyebrow: 'PERIODE',
                    meta: _periodLabel(),
                  ),
                  // Custom segmented underline tabs
                  _StatTabs(
                    controller: _tabController,
                    labels: const ['RINGKASAN', 'DETAIL'],
                    ink: ink,
                    secondary: secondary,
                    accent: accent,
                  ),
                  const Hairline(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSummaryTab(),
                        _buildDescriptiveTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _periodLabel() {
    switch (_selectedPeriod) {
      case 'quarter':
        return 'Kuartal';
      case 'year':
        return 'Tahun';
      default:
        return 'Bulan';
    }
  }

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _data == null
          ? const Center(child: Text('Belum ada data'))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _EditorialPeriodSelector(
                  selected: _selectedPeriod,
                  onChanged: _changePeriod,
                ),
                _EditorialSummaryStats(
                  income: _data!['income'] as num,
                  expense: _data!['expense'] as num,
                  net: _data!['net'] as num,
                  money: _money,
                ),
                _EditorialCategorySection(
                  data: List<Map<String, dynamic>>.from(
                    _data!['spend_by_cat'] as List,
                  ),
                  money: _money,
                ),
                _EditorialTransactionCount(
                  incomeCount: (_data!['transaction_counts']
                          as Map<String, int>)['income'] ??
                      0,
                  expenseCount: (_data!['transaction_counts']
                          as Map<String, int>)['expense'] ??
                      0,
                ),
                const SizedBox(height: AppTheme.space40),
              ],
            ),
    );
  }

  Widget _buildDescriptiveTab() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: _expenseStats == null && _incomeStats == null
          ? const Center(child: Text('Belum ada data'))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _EditorialPeriodSelector(
                  selected: _selectedPeriod,
                  onChanged: _changePeriod,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pageGutter,
                    AppTheme.space20,
                    AppTheme.pageGutter,
                    AppTheme.space24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('LEAD', color: secondary),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        'Lihat detail keuanganmu — rata-rata pengeluaran, pola, dan transaksi yang tidak biasa.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: ink,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_expenseStats != null && _expenseStats!.data.isNotEmpty)
                  _buildEditorialDescriptiveSection(
                    eyebrow: 'PENGELUARAN',
                    title: 'Pola pengeluaran',
                    stats: _expenseStats!,
                    color: ThemeUtils.getExpenseColor(context),
                    categoryData: _expenseCategoryData,
                  ),
                if (_incomeStats != null && _incomeStats!.data.isNotEmpty)
                  _buildEditorialDescriptiveSection(
                    eyebrow: 'PEMASUKAN',
                    title: 'Pola pemasukan',
                    stats: _incomeStats!,
                    color: ThemeUtils.getIncomeColor(context),
                    categoryData: _incomeCategoryData,
                  ),
                const SizedBox(height: AppTheme.space40),
              ],
            ),
    );
  }

  Widget _buildEditorialDescriptiveSection({
    required String eyebrow,
    required String title,
    required DescriptiveStatistics stats,
    required Color color,
    required Map<String, double> categoryData,
  }) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          eyebrow: eyebrow,
          title: title,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            0,
            AppTheme.pageGutter,
            AppTheme.space16,
          ),
          child: Text(
            'Total ${stats.data.length} transaksi pada periode ini.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: secondary,
            ),
          ),
        ),

        // Donut Chart
        if (categoryData.isNotEmpty) ...[
          const Hairline(),
          Padding(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('DISTRIBUSI', color: secondary),
                const SizedBox(height: AppTheme.space16),
                CategoryDonutChart(
                  categoryData: categoryData,
                  title: title,
                  primaryColor: color,
                ),
              ],
            ),
          ),
        ],

        // Key stats
        _EditorialStatRow(
          eyebrow: 'RATA-RATA',
          value: _money(stats.mean),
          caption: 'Per transaksi',
        ),
        _EditorialStatRow(
          eyebrow: 'MEDIAN',
          value: _money(stats.median),
          caption: 'Paling sering muncul',
        ),
        _EditorialStatRow(
          eyebrow: 'RENTANG',
          value: '${_money(stats.min)} – ${_money(stats.max)}',
          caption: 'Terkecil sampai terbesar',
        ),

        // Pattern
        _buildEditorialPattern(stats, color, ink, secondary),

        // Anomaly
        _buildEditorialAnomaly(stats, ink, secondary),

        const SizedBox(height: AppTheme.space24),
      ],
    );
  }

  Widget _buildEditorialPattern(
    DescriptiveStatistics stats,
    Color accentColor,
    Color ink,
    Color secondary,
  ) {
    String pattern;
    String explanation;
    final isDark = ThemeUtils.isDarkMode(context);
    Color patternColor;

    if (stats.skewness.abs() < 0.5) {
      pattern = 'Stabil';
      patternColor = isDark ? AppTheme.darkIncomeColor : AppTheme.incomeColor;
      explanation = 'Pengeluaranmu merata, tidak ada yang ekstrem.';
    } else if (stats.skewness < -0.5) {
      pattern = 'Boros';
      patternColor = isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor;
      explanation = 'Sering keluar uang banyak, coba lebih hemat.';
    } else {
      pattern = 'Normal';
      patternColor = ThemeUtils.getPrimaryColor(context);
      explanation = 'Biasanya kecil-kecil, kadang ada yang besar.';
    }

    return Column(
      children: [
        const Hairline(),
        Padding(
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
                children: [
                  AccentBar(width: 24, height: 2, color: patternColor),
                  const SizedBox(width: AppTheme.space8),
                  Eyebrow('POLA', color: secondary),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                pattern,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: patternColor,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                explanation,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorialAnomaly(
    DescriptiveStatistics stats,
    Color ink,
    Color secondary,
  ) {
    final normalCount = stats.zScores.where((z) => z.abs() < 2).length;
    final abnormalCount = stats.data.length - normalCount;
    final abnormalPercentage = stats.data.length > 0
        ? (abnormalCount / stats.data.length * 100)
        : 0.0;
    final isDark = ThemeUtils.isDarkMode(context);
    Color statusColor;
    String statusText;

    if (abnormalPercentage < 5) {
      statusColor = isDark ? AppTheme.darkIncomeColor : AppTheme.incomeColor;
      statusText = 'Aman';
    } else if (abnormalPercentage < 15) {
      statusColor = ThemeUtils.getPrimaryColor(context);
      statusText = 'Cukup baik';
    } else if (abnormalPercentage < 25) {
      statusColor = isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor;
      statusText = 'Perlu hati-hati';
    } else {
      statusColor = isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor;
      statusText = 'Waspada';
    }

    return Column(
      children: [
        const Hairline(),
        Padding(
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
                children: [
                  AccentBar(width: 24, height: 2, color: statusColor),
                  const SizedBox(width: AppTheme.space8),
                  Eyebrow('ANOMALI', color: secondary),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                statusText,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                '$abnormalCount dari ${stats.data.length} transaksi tidak wajar.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: secondary,
                ),
              ),
              if (stats.outliers.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space16),
                Eyebrow(
                  '${stats.outliers.length} TRANSAKSI ANEH',
                  color: secondary,
                  size: 10,
                ),
                const SizedBox(height: AppTheme.space8),
                Wrap(
                  spacing: AppTheme.space8,
                  runSpacing: AppTheme.space8,
                  children: stats.outliers.take(5).map((outlier) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        _money(outlier),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (stats.outliers.length > 5) ...[
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    '… dan ${stats.outliers.length - 5} lainnya',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Editorial segmented underline tabs for the statistics page header.
class _StatTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final Color ink;
  final Color secondary;
  final Color accent;

  const _StatTabs({
    required this.controller,
    required this.labels,
    required this.ink,
    required this.secondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            children: [
              for (int i = 0; i < labels.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => controller.animateTo(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space12,
                      ),
                      child: Column(
                        children: [
                          Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.6,
                              color: controller.index == i ? ink : secondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.space8),
                          Container(
                            height: 2,
                            color: controller.index == i
                                ? ThemeUtils.getAccentGreen(context)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Editorial period selector — segmented underline tabs.
class _EditorialPeriodSelector extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;

  const _EditorialPeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final green = ThemeUtils.getAccentGreen(context);

    Widget tab(String label, String value) {
      final isSelected = selected == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
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

    return Column(
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
          child: Row(
            children: [
              tab('BULAN', 'month'),
              tab('KUARTAL', 'quarter'),
              tab('TAHUN', 'year'),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }
}

/// Income / expense / net displayed editorial-style — full-width rows so
/// large numbers (millions, billions) never overflow.
class _EditorialSummaryStats extends StatelessWidget {
  final num income;
  final num expense;
  final num net;
  final String Function(num) money;

  const _EditorialSummaryStats({
    required this.income,
    required this.expense,
    required this.net,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final incomeColor = ThemeUtils.getIncomeColor(context);
    final expenseColor = ThemeUtils.getExpenseColor(context);
    final netColor = net >= 0 ? incomeColor : expenseColor;
    final secondary = ThemeUtils.getTextSecondary(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    return Column(
      children: [
        _SummaryRow(
          label: 'PEMASUKAN',
          value: money(income),
          color: incomeColor,
          secondary: secondary,
          hairline: hairline,
        ),
        _SummaryRow(
          label: 'PENGELUARAN',
          value: money(expense),
          color: expenseColor,
          secondary: secondary,
          hairline: hairline,
        ),
        _SummaryRow(
          label: 'SISA',
          value: money(net),
          color: netColor,
          secondary: secondary,
          hairline: hairline,
          isNet: true,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color secondary;
  final Color hairline;
  final bool isNet;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    required this.secondary,
    required this.hairline,
    this.isNet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: hairline, width: AppTheme.hairlineWidth),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pageGutter,
        vertical: AppTheme.space16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: secondary,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: isNet ? 26 : 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Editorial section showing top-5 spending categories with hairline rows
/// and a slim accent bar visualization.
class _EditorialCategorySection extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String Function(num) money;

  const _EditorialCategorySection({required this.data, required this.money});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final total = data.fold<double>(
      0,
      (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0),
    );

    return Column(
      children: [
        EditorialSectionHeader(
          eyebrow: 'KATEGORI',
          title: '${data.length} entri',
        ),
        for (final item in data.take(5))
          _CategoryEditorialRow(
            category: item['category'] as String? ?? '-',
            emoji: item['emoji'] as String? ?? '💰',
            amount: (item['total'] as num?)?.toDouble() ?? 0,
            total: total,
            money: money,
          ),
      ],
    );
  }
}

class _CategoryEditorialRow extends StatelessWidget {
  final String category;
  final String emoji;
  final double amount;
  final double total;
  final String Function(num) money;

  const _CategoryEditorialRow({
    required this.category,
    required this.emoji,
    required this.amount,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairline =
        isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;
    final percentage = total > 0 ? (amount / total * 100) : 0.0;

    return Column(
      children: [
        const Hairline(),
        Padding(
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
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                  ),
                  Text(
                    money(amount),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: hairline,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (percentage / 100).clamp(0.0, 1.0),
                        child: Container(color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
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
        ),
      ],
    );
  }
}

/// Two-column editorial transaction count.
class _EditorialTransactionCount extends StatelessWidget {
  final int incomeCount;
  final int expenseCount;

  const _EditorialTransactionCount({
    required this.incomeCount,
    required this.expenseCount,
  });

  @override
  Widget build(BuildContext context) {
    final incomeColor = ThemeUtils.getIncomeColor(context);
    final expenseColor = ThemeUtils.getExpenseColor(context);

    return Column(
      children: [
        const EditorialSectionHeader(
          eyebrow: 'JUMLAH',
          title: 'Transaksi',
        ),
        const Hairline(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space24,
            AppTheme.pageGutter,
            AppTheme.space24,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EditorialStat(
                    label: 'PEMASUKAN',
                    value: incomeCount.toString(),
                    caption: '$incomeCount transaksi',
                    valueSize: 40,
                    valueColor: incomeColor,
                  ),
                ),
                const VerticalHairline(),
                const SizedBox(width: AppTheme.space20),
                Expanded(
                  child: EditorialStat(
                    label: 'PENGELUARAN',
                    value: expenseCount.toString(),
                    caption: '$expenseCount transaksi',
                    valueSize: 40,
                    valueColor: expenseColor,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Editorial stat row: eyebrow + display value with caption + hairline.
class _EditorialStatRow extends StatelessWidget {
  final String eyebrow;
  final String value;
  final String? caption;

  const _EditorialStatRow({
    required this.eyebrow,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Column(
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space20,
            AppTheme.pageGutter,
            AppTheme.space20,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow, color: secondary),
                    if (caption != null) ...[
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        caption!,
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
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
