import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/trend_analysis.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';
import 'package:fl_chart/fl_chart.dart';

class TrendAnalysisPage extends StatefulWidget {
  const TrendAnalysisPage({super.key});

  @override
  State<TrendAnalysisPage> createState() => _TrendAnalysisPageState();
}

class _TrendAnalysisPageState extends State<TrendAnalysisPage> {
  bool _loading = true;
  String _period = 'monthly'; // 'weekly' or 'monthly'

  // Data untuk analisis
  List<Map<String, dynamic>> _transactions = [];
  List<double> _expenseValues = [];
  List<double> _incomeValues = [];
  List<String> _labels = [];

  TrendAnalysis? _expenseTrend;
  CorrelationAnalysis? _correlation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = context.read<AppDatabase>();
      final auth = context.read<AuthNotifier>();
      final user = auth.user;

      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Ambil transaksi 6 bulan terakhir
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 6, 1);
      final end = DateTime(now.year, now.month + 1, 0);

      final transactions = await db.getTransactions(
        startDate: DateFormat('yyyy-MM-dd').format(start),
        endDate: DateFormat('yyyy-MM-dd').format(end),
      );
      // Sort ascending for trend analysis
      transactions.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      // Kelompokkan berdasarkan periode
      final groupedData = _groupByPeriod(transactions);

      // Ekstrak nilai untuk analisis
      _expenseValues = groupedData.map((g) => g['expense'] as double).toList();
      _incomeValues = groupedData.map((g) => g['income'] as double).toList();
      _labels = groupedData.map((g) => g['label'] as String).toList();

      // Lakukan analisis tren (only if data available)
      if (_expenseValues.length >= 2) {
        _expenseTrend = TrendAnalysisUtils.linearRegression(_expenseValues);
        _correlation = TrendAnalysisUtils.correlation(
          _incomeValues,
          _expenseValues,
        );
      }

      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnackbar(context, 'Gagal memuat analisis tren: $e');
    }
  }

  List<Map<String, dynamic>> _groupByPeriod(
    List<Map<String, dynamic>> transactions,
  ) {
    final Map<String, Map<String, double>> groups = {};

    for (var tx in transactions) {
      final date = DateTime.parse(tx['date'] as String);
      String key;

      if (_period == 'weekly') {
        // Format: Week 1 Jan, Week 2 Jan, etc
        final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
        key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-W$weekOfMonth';
      } else {
        // Format: Jan 2024, Feb 2024, etc
        key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = {'income': 0, 'expense': 0};
      }

      final amount = (tx['amount'] as num).toDouble();
      if (tx['type'] == 'income') {
        groups[key]!['income'] = groups[key]!['income']! + amount;
      } else {
        groups[key]!['expense'] = groups[key]!['expense']! + amount;
      }
    }

    // Konversi ke list dan urutkan
    final sorted = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted
        .map(
          (e) => {
            'key': e.key,
            'label': _period == 'weekly'
                ? 'W${((DateTime.parse('${e.key.split('-W')[0]}-01').day - 1) ~/ 7) + 1} ${DateFormat('MMM').format(DateTime.parse('${e.key.split('-W')[0]}-01'))}'
                : DateFormat('MMM yyyy').format(DateTime.parse('${e.key}-01')),
            'income': e.value['income']!,
            'expense': e.value['expense']!,
          },
        )
        .toList();
  }

  String _formatMoney(double value) {
    return 'Rp ${NumberFormat.decimalPattern('id').format(value.round())}';
  }

  Widget _buildPeriodSelector() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    Widget tab(String label, String value) {
      final isSelected = _period == value;
      return Expanded(
        child: InkWell(
          onTap: () {
            if (_period != value) {
              setState(() => _period = value);
              _loadData();
            }
          },
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
                  color: isSelected
                      ? ThemeUtils.getAccentGreen(context)
                      : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
          child: Row(
            children: [
              tab('BULANAN', 'monthly'),
              tab('MINGGUAN', 'weekly'),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
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
            : _transactions.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorialHeader(
                        eyebrow: 'TREN',
                        title: 'Analisa tren.',
                        titleSize: 36,
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.pageGutter,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow('KOSONG', color: secondary),
                            const SizedBox(height: AppTheme.space12),
                            DisplayTitle(
                              'Belum ada\ndata transaksi.',
                              size: 28,
                            ),
                            const SizedBox(height: AppTheme.space12),
                            Text(
                              'Tambah transaksi untuk melihat analisa tren.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: secondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      EditorialHeader(
                        eyebrow: 'TREN',
                        title: 'Analisa tren.',
                        titleSize: 36,
                        metaEyebrow: 'PERIODE',
                        meta: _period == 'monthly'
                            ? 'Per bulan'
                            : 'Per minggu',
                      ),
                      _buildPeriodSelector(),
                      _buildTrendChart(),
                      _buildExpenseTrendInsight(),
                      _buildPredictionCard(),
                      _buildCorrelationCard(),
                      _buildStatisticsCard(),
                      const SizedBox(height: AppTheme.space40),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_expenseValues.isEmpty) return const SizedBox();
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairline =
        isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;

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
          Row(
            children: [
              AccentBar(width: 24, height: 2, color: accent),
              const SizedBox(width: AppTheme.space8),
              Eyebrow('GRAFIK', color: secondary),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            'Pengeluaran ${_period == 'monthly' ? 'per bulan' : 'per minggu'}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: ink,
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final textStyle = TextStyle(
                          color:
                              touchedSpot.bar.gradient?.colors.first ??
                              touchedSpot.bar.color ??
                              Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        );
                        return LineTooltipItem(
                          'Rp${NumberFormat.decimalPattern('id').format(touchedSpot.y.round())}',
                          textStyle,
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getChartInterval(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: hairline,
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _labels.length) {
                          return const Text('');
                        }
                        final skipInterval = _period == 'weekly' ? 4 : 2;
                        if (_labels.length > 4 && index % skipInterval != 0) {
                          return const Text('');
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _labels[index],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: secondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _formatShortMoney(value),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: hairline, width: 1),
                    left: BorderSide(color: hairline, width: 1),
                  ),
                ),
                minX: 0,
                maxX: (_expenseValues.length - 1).toDouble(),
                minY: 0,
                maxY: _getMaxY(),
                lineBarsData: [
                  // Data aktual
                  LineChartBarData(
                    spots: _expenseValues.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: expense,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: expense,
                          strokeWidth: 0,
                          strokeColor: expense,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Garis tren (prediksi)
                  if (_expenseTrend != null)
                    LineChartBarData(
                      spots: _expenseTrend!.predictions
                          .asMap()
                          .entries
                          .where((e) => e.key < _expenseValues.length)
                          .map((e) {
                            return FlSpot(e.key.toDouble(), e.value);
                          })
                          .toList(),
                      isCurved: false,
                      color: accent,
                      barWidth: 1.5,
                      isStrokeCapRound: true,
                      dashArray: const [4, 3],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space20),
          // Legend — flat editorial
          Row(
            children: [
              _buildLegendItem(expense, 'AKTUAL', isDashed: false),
              const SizedBox(width: AppTheme.space24),
              _buildLegendItem(accent, 'PREDIKSI', isDashed: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {required bool isDashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 2,
          child: isDashed
              ? CustomPaint(
                  painter: DashedLinePainter(color: color),
                )
              : Container(color: color),
        ),
        const SizedBox(width: AppTheme.space8),
        Eyebrow(label, color: color, size: 10),
      ],
    );
  }

  Widget _buildExpenseTrendInsight() {
    if (_expenseTrend == null) return const SizedBox();

    final changePercent = _expenseTrend!.averageChangePercent;
    final isIncreasing = changePercent > 0;
    final absPercent = changePercent.abs();

    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final income = ThemeUtils.getIncomeColor(context);
    final accentColor = isIncreasing ? expense : income;

    return Column(
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space24,
            AppTheme.pageGutter,
            AppTheme.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AccentBar(width: 24, height: 2, color: accentColor),
                  const SizedBox(width: AppTheme.space8),
                  Eyebrow(isIncreasing ? 'NAIK' : 'TURUN', color: accentColor),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                '${isIncreasing ? '+' : '-'}${absPercent.toStringAsFixed(1)}%',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 56,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.5,
                  color: accentColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                'rata-rata setiap ${_period == 'monthly' ? 'bulan' : 'minggu'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: secondary,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                isIncreasing
                    ? 'Pengeluaranmu konsisten naik. Coba cek dan kontrol agar tidak melewati anggaran.'
                    : 'Pengeluaranmu menurun stabil. Pertahankan kebiasaan baik ini.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard() {
    if (_expenseTrend == null || _expenseValues.isEmpty) {
      return const SizedBox();
    }

    final nextPrediction = _expenseTrend!.predict(
      _expenseValues.length.toDouble(),
    );
    final currentAvg = TrendAnalysisUtils.mean(_expenseValues);
    final change = currentAvg == 0
        ? 0.0
        : ((nextPrediction - currentAvg) / currentAvg * 100);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isUp = change > 0;
    final changeColor = isUp
        ? ThemeUtils.getExpenseColor(context)
        : ThemeUtils.getIncomeColor(context);

    return Column(
      children: [
        const EditorialSectionHeader(
          eyebrow: 'PREDIKSI',
          title: 'Estimasi periode depan',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            0,
            AppTheme.pageGutter,
            AppTheme.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _period == 'monthly'
                    ? 'Bulan depan diperkirakan'
                    : 'Minggu depan diperkirakan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                _formatMoney(nextPrediction),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.0,
                  color: ink,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: accent,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: changeColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    'dari rata-rata',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: secondary,
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

  Widget _buildCorrelationCard() {
    if (_correlation == null) return const SizedBox();
    final r = _correlation!.correlation;
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    final String narrative;
    if (r > 0.5) {
      narrative =
          'Saat pemasukan naik, pengeluaran cenderung ikut naik. Coba atur agar tetap seimbang.';
    } else if (r < -0.5) {
      narrative =
          'Saat pemasukan naik, pengeluaran justru turun. Pola yang sehat — pertahankan.';
    } else {
      narrative =
          'Pemasukan dan pengeluaran tidak terlalu berhubungan. Polanya sudah konsisten.';
    }

    return Column(
      children: [
        const EditorialSectionHeader(
          eyebrow: 'KORELASI',
          title: 'Pemasukan & pengeluaran',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            0,
            AppTheme.pageGutter,
            AppTheme.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    r.toStringAsFixed(2),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 56,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                      color: ink,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Eyebrow(
                      _correlation!.strength.toUpperCase(),
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                narrative,
                style: GoogleFonts.inter(
                  fontSize: 14,
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

  Widget _buildStatisticsCard() {
    if (_expenseValues.isEmpty) return const SizedBox();
    final avgExpense = TrendAnalysisUtils.mean(_expenseValues);
    final stdDev = TrendAnalysisUtils.standardDeviation(_expenseValues);
    final maxExpense = _expenseValues.reduce((a, b) => a > b ? a : b);
    final minExpense = _expenseValues.reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        const EditorialSectionHeader(
          eyebrow: 'RINGKASAN',
          title: 'Angka penting',
        ),
        _buildStatRow(
          label: 'RATA-RATA',
          caption: 'Per ${_period == 'monthly' ? 'bulan' : 'minggu'}',
          value: _formatMoney(avgExpense),
        ),
        _buildStatRow(
          label: 'TERTINGGI',
          caption: 'Periode dengan pengeluaran terbesar',
          value: _formatMoney(maxExpense),
        ),
        _buildStatRow(
          label: 'TERENDAH',
          caption: 'Periode dengan pengeluaran terkecil',
          value: _formatMoney(minExpense),
        ),
        _buildStatRow(
          label: 'DEVIASI',
          caption: 'Selisih naik–turun',
          value: _formatMoney(stdDev),
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required String label,
    required String caption,
    required String value,
  }) {
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
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(label, color: secondary),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      caption,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondary,
                      ),
                    ),
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

  double _getMaxY() {
    if (_expenseValues.isEmpty) return 100;

    final maxActual = _expenseValues.reduce((a, b) => a > b ? a : b);
    final maxPrediction =
        _expenseTrend?.predictions
            .where((p) => p > 0)
            .reduce((a, b) => a > b ? a : b) ??
        maxActual;

    final max = maxActual > maxPrediction ? maxActual : maxPrediction;
    return (max * 1.2).ceilToDouble();
  }

  double _getChartInterval() {
    final maxY = _getMaxY();
    if (maxY < 1000000) return 200000;
    if (maxY < 5000000) return 1000000;
    return 2000000;
  }

  String _formatShortMoney(double value) {
    if (value >= 1000000) {
      return 'Rp${(value / 1000000).toStringAsFixed(0)}jt';
    } else if (value >= 1000) {
      return 'Rp${(value / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp${value.toStringAsFixed(0)}';
  }
}

// Custom painter untuk garis putus-putus
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    const dashWidth = 3;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
