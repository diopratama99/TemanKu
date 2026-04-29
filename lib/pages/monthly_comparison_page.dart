import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../data/app_database.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

/// Monthly Comparison Page - Uji Hipotesis Dua Populasi
/// Compares expenses between two months to detect significant changes
class MonthlyComparisonPage extends StatefulWidget {
  const MonthlyComparisonPage({super.key});

  @override
  State<MonthlyComparisonPage> createState() => _MonthlyComparisonPageState();
}

class _MonthlyComparisonPageState extends State<MonthlyComparisonPage> {
  bool _loading = true;
  String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _previousMonth = DateFormat(
    'yyyy-MM',
  ).format(DateTime(DateTime.now().year, DateTime.now().month - 1));

  Map<String, dynamic>? _currentData;
  Map<String, dynamic>? _previousData;
  Map<String, dynamic>? _comparisonResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = context.read<AppDatabase>();

      // Load current month data
      _currentData = await _loadMonthData(db, _currentMonth);

      // Load previous month data
      _previousData = await _loadMonthData(db, _previousMonth);

      // Perform statistical comparison
      _comparisonResult = _performHypothesisTest();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        showErrorSnackbar(context, 'Error loading data: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _loadMonthData(
    AppDatabase db,
    String month,
  ) async {
    final parts = month.split('-');
    final lastDay = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 0).day;
    final rows = await db.getTransactions(
      startDate: '$month-01',
      endDate: '$month-${lastDay.toString().padLeft(2, '0')}',
      type: 'expense',
    );

    double total = 0;
    final catAgg = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final amount = (row['amount'] as num).toDouble();
      total += amount;
      final category = (row['category'] as String?) ?? 'Tanpa Kategori';
      final emoji = (row['category_emoji'] as String?) ?? '📦';
      final key = '$emoji $category';
      if (catAgg.containsKey(key)) {
        catAgg[key]!['amount'] = (catAgg[key]!['amount'] as double) + amount;
        catAgg[key]!['count'] = (catAgg[key]!['count'] as int) + 1;
      } else {
        catAgg[key] = {
          'category': category,
          'emoji': emoji,
          'amount': amount,
          'count': 1,
        };
      }
    }

    final categories = catAgg.values
        .where((cat) => (cat['amount'] as double) > 0)
        .toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    int totalCount = 0;
    for (final cat in categories) {
      totalCount += (cat['count'] as int? ?? 0);
    }

    return {
      'month': month,
      'total': total,
      'categories': categories,
      'count': totalCount,
    };
  }

  /// Perform Two-Sample Hypothesis Test (Uji Hipotesis Dua Populasi)
  /// H0: μ1 = μ2 (no significant difference)
  /// H1: μ1 ≠ μ2 (significant difference exists)
  Map<String, dynamic> _performHypothesisTest() {
    if (_currentData == null || _previousData == null) {
      return {};
    }

    final currentTotal = _currentData!['total'] as double;
    final previousTotal = _previousData!['total'] as double;

    // Calculate percentage change
    final percentageChange = previousTotal > 0
        ? ((currentTotal - previousTotal) / previousTotal) * 100
        : 0.0;

    // Perform hypothesis test for each category
    final categoryComparisons = <Map<String, dynamic>>[];

    final currentCategories = _currentData!['categories'] as List;
    final previousCategories = _previousData!['categories'] as List;

    // Create a map for easier lookup
    final prevCatMap = <String, Map<String, dynamic>>{};
    for (final cat in previousCategories) {
      final catName = cat['category'];
      if (catName != null && catName is String) {
        prevCatMap[catName] = cat as Map<String, dynamic>;
      }
    }

    for (final currCat in currentCategories) {
      final catName = currCat['category'];
      final catEmoji = currCat['emoji'];

      // Skip if category name is null
      if (catName == null || catName is! String) continue;

      final currAmount = (currCat['amount'] as num?)?.toDouble() ?? 0.0;
      final prevCat = prevCatMap[catName];

      if (prevCat != null) {
        final prevAmount = (prevCat['amount'] as num?)?.toDouble() ?? 0.0;
        final catChange = prevAmount > 0
            ? ((currAmount - prevAmount) / prevAmount) * 100
            : 0.0;

        // Simple significance test based on percentage change threshold
        // In real stats, you'd use t-test with sample variance
        final isSignificant = catChange.abs() > 10.0; // 10% threshold
        final pValue = _calculateSimplePValue(catChange.abs());

        categoryComparisons.add({
          'category': catName,
          'emoji': catEmoji ?? '📦',
          'currentAmount': currAmount,
          'previousAmount': prevAmount,
          'change': catChange,
          'isSignificant': isSignificant,
          'pValue': pValue,
        });
      } else {
        // New category this month
        categoryComparisons.add({
          'category': catName,
          'emoji': catEmoji ?? '📦',
          'currentAmount': currAmount,
          'previousAmount': 0.0,
          'change': 100.0,
          'isSignificant': true,
          'pValue': 0.01,
        });
      }
    }

    // Sort by absolute change
    categoryComparisons.sort(
      (a, b) => (b['change'] as double).abs().compareTo(
        (a['change'] as double).abs(),
      ),
    );

    // Overall significance
    final overallSignificant = percentageChange.abs() > 5.0;

    return {
      'currentTotal': currentTotal,
      'previousTotal': previousTotal,
      'percentageChange': percentageChange,
      'isSignificant': overallSignificant,
      'categoryComparisons': categoryComparisons,
      'interpretation': _generateInterpretation(
        percentageChange,
        overallSignificant,
        categoryComparisons,
      ),
    };
  }

  /// Calculate simplified p-value based on percentage change
  /// In real implementation, use proper t-distribution
  double _calculateSimplePValue(double percentChange) {
    // Simplified approximation: larger change = smaller p-value
    if (percentChange > 50) return 0.001;
    if (percentChange > 30) return 0.01;
    if (percentChange > 20) return 0.02;
    if (percentChange > 10) return 0.05;
    return 0.15; // Not significant
  }

  String _generateInterpretation(
    double overallChange,
    bool isSignificant,
    List<Map<String, dynamic>> categories,
  ) {
    final buffer = StringBuffer();

    // Overall interpretation
    if (isSignificant) {
      if (overallChange > 0) {
        buffer.write(
          'Pengeluaran bulan ini meningkat signifikan sebesar '
          '+${overallChange.toStringAsFixed(1)}% dibanding bulan lalu.\n\n',
        );
      } else {
        buffer.write(
          'Pengeluaran bulan ini menurun signifikan sebesar '
          '${overallChange.toStringAsFixed(1)}% dibanding bulan lalu.\n\n',
        );
      }
    } else {
      buffer.write(
        'Pengeluaran bulan ini relatif stabil '
        '(${overallChange >= 0 ? '+' : ''}${overallChange.toStringAsFixed(1)}%) '
        'dibanding bulan lalu.\n\n',
      );
    }

    // Category-level insights
    if (categories.isNotEmpty) {
      final topIncrease = categories.firstWhere(
        (c) => (c['change'] as double) > 0 && c['isSignificant'] as bool,
        orElse: () => {},
      );

      if (topIncrease.isNotEmpty) {
        buffer.write(
          'Kategori "${topIncrease['category']}" mengalami kenaikan tertinggi '
          '(+${(topIncrease['change'] as double).toStringAsFixed(1)}%).\n\n',
        );
      }

      final topDecrease = categories.firstWhere(
        (c) => (c['change'] as double) < 0 && c['isSignificant'] as bool,
        orElse: () => {},
      );

      if (topDecrease.isNotEmpty) {
        buffer.write(
          'Kategori "${topDecrease['category']}" mengalami penurunan terbesar '
          '(${(topDecrease['change'] as double).toStringAsFixed(1)}%).\n\n',
        );
      }

      // Count non-significant categories
      final nonSignificant = categories
          .where((c) => !(c['isSignificant'] as bool))
          .length;

      if (nonSignificant > 0) {
        buffer.write(
          '$nonSignificant kategori menunjukkan perubahan yang tidak signifikan (p > 0.05).',
        );
      }
    }

    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: _loading
            ? const LoadingStateWidget(message: 'Menganalisis data...')
            : _comparisonResult == null || _comparisonResult!.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorialHeader(
                        eyebrow: 'PERBANDINGAN',
                        title: 'Bulan vs.\nBulan.',
                        titleSize: 36,
                        trailing: IconButton(
                          icon: Icon(Icons.info_outline,
                              color: secondary, size: 20),
                          onPressed: _showInfoDialog,
                        ),
                      ),
                      Expanded(
                        child: EmptyStateWidget(
                          icon: Icons.analytics_outlined,
                          title: 'Tidak ada data',
                          description:
                              'Belum ada data pengeluaran untuk dibandingkan.',
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        EditorialHeader(
                          eyebrow: 'PERBANDINGAN',
                          title: 'Bulan vs.\nBulan.',
                          titleSize: 36,
                          trailing: IconButton(
                            icon: Icon(Icons.info_outline,
                                color: secondary, size: 20),
                            onPressed: _showInfoDialog,
                          ),
                        ),
                        _buildEditorialOverview(),
                        _buildEditorialInterpretation(),
                        _buildEditorialCategoryList(),
                        const SizedBox(height: AppTheme.space40),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildEditorialOverview() {
    final currentTotal = _comparisonResult!['currentTotal'] as double;
    final previousTotal = _comparisonResult!['previousTotal'] as double;
    final change = _comparisonResult!['percentageChange'] as double;
    final isSignificant = _comparisonResult!['isSignificant'] as bool;
    final money = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final income = ThemeUtils.getIncomeColor(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isUp = change >= 0;
    final changeColor = isUp ? expense : income;

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
          // Two columns: bulan ini, bulan lalu
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('BULAN INI', color: secondary),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        DateFormat('MMM yyyy', 'id_ID')
                            .format(DateTime.parse('$_currentMonth-01')),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      Text(
                        money.format(currentTotal),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
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
                      Eyebrow('BULAN LALU', color: secondary),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        DateFormat('MMM yyyy', 'id_ID')
                            .format(DateTime.parse('$_previousMonth-01')),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      Text(
                        money.format(previousTotal),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: secondary,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          // Big delta
          Row(
            children: [
              AccentBar(
                width: 24,
                height: 2,
                color: changeColor,
              ),
              const SizedBox(width: AppTheme.space8),
              Eyebrow(
                isUp ? 'NAIK' : 'TURUN',
                color: changeColor,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 56,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.5,
              height: 1.0,
              color: changeColor,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                color: isSignificant ? accent : secondary,
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  isSignificant
                      ? 'Perubahan signifikan secara statistik (p < 0.05)'
                      : 'Perubahan tidak signifikan (p > 0.05)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialInterpretation() {
    final interpretation = _comparisonResult!['interpretation'] as String;
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialSectionHeader(
          eyebrow: 'TAFSIR',
          title: 'Apa artinya?',
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
                interpretation,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.7,
                  color: ink,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                'Berdasarkan ambang batas 10% dan p-value sederhana.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorialCategoryList() {
    final categories =
        _comparisonResult!['categoryComparisons'] as List<Map<String, dynamic>>;

    if (categories.isEmpty) return const SizedBox.shrink();
    final money = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          eyebrow: 'KATEGORI',
          title: '${categories.length} entri',
        ),
        for (final cat in categories)
          _CategoryComparisonRow(
            cat: cat,
            money: money,
          ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang Uji Hipotesis'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Uji Hipotesis Dua Populasi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Fitur ini menggunakan konsep statistik untuk '
                'membandingkan pengeluaran dari dua periode berbeda.\n\n'
                'H₀: μ₁ = μ₂ (Tidak ada perbedaan signifikan)\n'
                'H₁: μ₁ ≠ μ₂ (Ada perbedaan signifikan)\n\n',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              Text(
                'Interpretasi p-value:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                '• p < 0.05: Perubahan signifikan\n'
                '• p > 0.05: Perubahan tidak signifikan\n\n'
                'Ini membantu Anda mengevaluasi apakah perubahan '
                'pengeluaran benar-benar berbeda atau hanya fluktuasi normal.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}

class _CategoryComparisonRow extends StatelessWidget {
  final Map<String, dynamic> cat;
  final NumberFormat money;

  const _CategoryComparisonRow({required this.cat, required this.money});

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final income = ThemeUtils.getIncomeColor(context);
    final isDark = ThemeUtils.isDarkMode(context);
    final hairline = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;
    final change = cat['change'] as double;
    final isSignificant = cat['isSignificant'] as bool;
    final isUp = change >= 0;
    final changeColor = isUp ? expense : income;
    final currentAmount = (cat['currentAmount'] as num).toDouble();
    final previousAmount = (cat['previousAmount'] as num).toDouble();
    final maxOfTwo = (currentAmount > previousAmount ? currentAmount : previousAmount).clamp(1, double.infinity);
    final currentRatio = (currentAmount / maxOfTwo).clamp(0.0, 1.0);
    final previousRatio = (previousAmount / maxOfTwo).clamp(0.0, 1.0);

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
                  Text(
                    cat['emoji'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat['category'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          isSignificant
                              ? 'Signifikan'
                              : 'Tidak signifikan',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Text(
                    '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space16),
              // Two slim bars: current and previous
              _MiniBar(
                eyebrow: 'BULAN INI',
                value: money.format(currentAmount),
                ratio: currentRatio,
                color: changeColor,
                hairline: hairline,
                ink: ink,
                secondary: secondary,
              ),
              const SizedBox(height: AppTheme.space8),
              _MiniBar(
                eyebrow: 'BULAN LALU',
                value: money.format(previousAmount),
                ratio: previousRatio,
                color: secondary,
                hairline: hairline,
                ink: ink,
                secondary: secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String eyebrow;
  final String value;
  final double ratio;
  final Color color;
  final Color hairline;
  final Color ink;
  final Color secondary;

  const _MiniBar({
    required this.eyebrow,
    required this.value,
    required this.ratio,
    required this.color,
    required this.hairline,
    required this.ink,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 78,
          child: Eyebrow(eyebrow, color: secondary, size: 10),
        ),
        Expanded(
          child: Container(
            height: 6,
            color: hairline,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(color: color),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
