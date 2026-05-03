import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/balance_card.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

/// Editorial dashboard — paper-style magazine layout.
///
/// Section structure:
///   Header (eyebrow EDISI · display "Beranda" · meta on right)
///   Brankas (balance card)
///   Fitur (feature grid — text-led with hairline borders)
///   Ringkasan (goals + budgets editorial cards)
///   Terkini (latest transactions as flat list rows)
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  late DateTime _start;
  late DateTime _end;

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
    final auth = context.read<AuthNotifier>();
    final user = auth.user;

    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final data = await db.dashboardData(_iso(_start), _iso(_end));
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _money(num v) => 'Rp ${NumberFormat.decimalPattern('id').format(v)}';

  // ============================================================
  // Header & sections
  // ============================================================

  Widget _buildHeader() {
    final edition = DateFormat(
      'MMMM yyyy',
      'id',
    ).format(DateTime.now()).toUpperCase();
    final secondary = ThemeUtils.getTextSecondary(context);

    return EditorialHeader(
      eyebrow: 'EDISI $edition',
      title: 'Beranda.',
      titleSize: 40,
      trailing: Transform.translate(
        offset: const Offset(0, -16),
        child: IconButton(
          onPressed: _showInfoDialog,
          icon: Icon(
            Icons.info_outline,
            size: 20,
            color: secondary,
          ),
          tooltip: 'Tentang angka di halaman ini',
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
        ),
      ),
    );
  }

  /// Editorial info dialog — explains the difference between the
  /// cumulative "Sisa Saldo" and the per-month figures (PEMASUKAN,
  /// PENGELUARAN, budgets, latest transactions). Surfaced via the info
  /// icon in the top-right of the dashboard header so users don't
  /// mistake this month's net for their total wallet.
  Future<void> _showInfoDialog() async {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    // `secondary` is used only for the close-icon tint below.
    final paper = ThemeUtils.getBackgroundColor(context);
    final green = ThemeUtils.getAccentGreen(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: paper,
        surfaceTintColor: paper,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.pageGutter,
          vertical: AppTheme.space32,
        ),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: hairline, width: AppTheme.hairlineWidth),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space24,
            AppTheme.pageGutter,
            AppTheme.space20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — eyebrow + title + close
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AccentBar(
                              width: 16,
                              height: 2,
                              color: green,
                            ),
                            const SizedBox(width: AppTheme.space8),
                            const Eyebrow('INFORMASI'),
                          ],
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          'Tentang angka di halaman ini',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            height: 1.2,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close, size: 20, color: secondary),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space20),
              const Hairline(),
              const SizedBox(height: AppTheme.space20),

              // Body — three info rows
              _InfoRow(
                ink: ink,
                accent: green,
                eyebrow: 'SISA SALDO',
                body:
                    'Akumulasi dari net transaksi seluruh bulan sebelumnya '
                    'ditambah net bulan ini. Angka ini mencerminkan total '
                    'dana kamu, bukan cuma selisih bulan ini.',
              ),
              const SizedBox(height: AppTheme.space16),
              _InfoRow(
                ink: ink,
                accent: green,
                eyebrow: 'PEMASUKAN & PENGELUARAN',
                body:
                    'Hanya mencakup transaksi yang terjadi pada bulan ini.',
              ),
              const SizedBox(height: AppTheme.space24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('MENGERTI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureMenu() {
    final features = <_FeatureItem>[
      _FeatureItem(
        eyebrow: '01',
        label: 'Transaksi',
        caption: 'Riwayat lengkap',
        icon: Icons.receipt_long_outlined,
        onTap: () => Navigator.pushNamed(context, '/transactions'),
      ),
      _FeatureItem(
        eyebrow: '02',
        label: 'Analisa Tren',
        caption: 'Prediksi & korelasi',
        icon: Icons.show_chart,
        onTap: () => Navigator.pushNamed(context, '/trend_analysis'),
      ),
      _FeatureItem(
        eyebrow: '03',
        label: 'Perbandingan',
        caption: 'Uji hipotesis bulan',
        icon: Icons.bar_chart_rounded,
        onTap: () => Navigator.pushNamed(context, '/monthly_comparison'),
      ),
      _FeatureItem(
        eyebrow: '04',
        label: 'Kategori',
        caption: 'Atur tag transaksi',
        icon: Icons.label_outline,
        onTap: () => Navigator.pushNamed(context, '/categories'),
      ),
      _FeatureItem(
        eyebrow: '05',
        label: 'Tabungan',
        caption: 'Target dan alokasi',
        icon: Icons.savings_outlined,
        onTap: () => Navigator.pushNamed(context, '/savings'),
      ),
      _FeatureItem(
        eyebrow: '06',
        label: 'Hutang / Piutang',
        caption: 'Catat hutang & tagihan',
        icon: Icons.handshake_outlined,
        onTap: () => Navigator.pushNamed(context, '/debts'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialSectionHeader(
          eyebrow: 'TemanKu',
          title: 'Daftar Fitur',
          eyebrowColor: AppTheme.accentGreen,
        ),
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pageGutter,
            vertical: AppTheme.space20,
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            childAspectRatio: 1.6,
            children: features.map((item) => _FeatureCell(item: item)).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthNotifier>();
    final paper = ThemeUtils.getBackgroundColor(context);

    if (_loading) {
      return Container(
        color: paper,
        child: const LoadingStateWidget(message: 'Menyiapkan halaman...'),
      );
    }

    if (_data == null) {
      return Container(
        color: paper,
        child: EmptyStateWidget(
          eyebrow: 'BELUM ADA EDISI',
          icon: Icons.account_balance_wallet_outlined,
          title: 'Halaman masih kosong',
          description:
              'Mulai catat transaksi pertama untuk membuka edisi keuanganmu.',
          actionLabel: 'Tulis transaksi',
          onAction: () => Navigator.pushNamed(context, '/add'),
        ),
      );
    }

    return Container(
      color: paper,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppTheme.space64),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ModernBalanceCard(
                    // Use the cumulative `balance` (carry-over + current
                    // month delta) so Sisa Saldo reflects the full wallet,
                    // not just this month's net. Fallback to `net` for
                    // cached payloads that predate the carry-over field.
                    balance: (_data!['balance'] ?? _data!['net']) as num,
                    income: _data!['income'] as num,
                    expense: _data!['expense'] as num,
                    onTap: () => Navigator.pushNamed(context, '/accounts'),
                  ),
                  const Hairline(),
                  _buildFeatureMenu(),
                  _buildQuickStats(),
                  _buildRecentTransactions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final goals = List<Map<String, dynamic>>.from(
      _data!['active_goals'] as List,
    );
    final budgets = List<Map<String, dynamic>>.from(_data!['budgets'] as List);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialSectionHeader(
          eyebrow: 'RINGKASAN',
          title: 'Tabungan & Budget',
        ),
        const Hairline(),
        if (goals.isEmpty && budgets.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageGutter,
              AppTheme.space24,
              AppTheme.pageGutter,
              AppTheme.space32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum ada angka untuk ditampilkan.',
                  style: AppTheme.pullQuote(color: secondary),
                ),
                const SizedBox(height: AppTheme.space16),
                Text(
                  'Tambahkan target tabungan atau atur batas pengeluaran '
                  'kategori untuk mulai melacak progres.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: secondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/savings'),
                  child: const Text('ATUR TARGET'),
                ),
              ],
            ),
          )
        else ...[
          if (goals.isNotEmpty) _buildGoalsSection(goals),
          if (budgets.isNotEmpty) _buildBudgetsSection(budgets),
        ],
      ],
    );
  }

  Widget _buildGoalsSection(List<Map<String, dynamic>> goals) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final incomeColor = ThemeUtils.getIncomeColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageGutter,
        AppTheme.space20,
        AppTheme.pageGutter,
        AppTheme.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentBar(
                width: 16,
                height: 2,
                color: ThemeUtils.getAccentGreen(context),
              ),
              const SizedBox(width: AppTheme.space8),
              const Eyebrow('TABUNGAN'),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/savings'),
                child: Row(
                  children: [
                    Eyebrow('LIHAT', color: secondary, size: 10),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 12, color: secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          ...goals.take(2).map((g) {
            final allocated = (g['allocated'] as num? ?? 0).toDouble();
            final target = (g['target_amount'] as num? ?? 0).toDouble();
            final progress = target > 0
                ? (allocated / target).clamp(0.0, 1.0)
                : 0.0;
            final percent = (progress * 100).toInt();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          g['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: incomeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: ThemeUtils.isDarkMode(context)
                        ? AppTheme.darkHairlineColor
                        : AppTheme.hairlineColor,
                    valueColor: AlwaysStoppedAnimation(incomeColor),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    '${_money(allocated)} dari ${_money(target)}',
                    style: GoogleFonts.inter(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBudgetsSection(List<Map<String, dynamic>> budgets) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final expenseColor = ThemeUtils.getExpenseColor(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ThemeUtils.isDarkMode(context)
                ? AppTheme.darkHairlineColor
                : AppTheme.hairlineColor,
            width: AppTheme.hairlineWidth,
          ),
        ),
      ),
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
              const Eyebrow('BUDGET'),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/budgets'),
                child: Row(
                  children: [
                    Eyebrow('LIHAT', color: secondary, size: 10),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 12, color: secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          ...budgets.take(2).map((b) {
            final spent = (b['spent'] as num? ?? 0).toDouble();
            final limit = (b['limit_amount'] as num? ?? 0).toDouble();
            final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
            final percent = (progress * 100).toInt();
            final isOver = progress > 0.9;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          b['category'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isOver ? expenseColor : ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: ThemeUtils.isDarkMode(context)
                        ? AppTheme.darkHairlineColor
                        : AppTheme.hairlineColor,
                    valueColor: AlwaysStoppedAnimation(
                      isOver ? expenseColor : ink,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    '${_money(spent)} dari ${_money(limit)}',
                    style: GoogleFonts.inter(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final recent = _data!['recent'] as List?;
    if (recent == null || recent.isEmpty) return const SizedBox.shrink();

    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          eyebrow: 'TERKINI',
          title: 'Catatan terbaru',
          trailing: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/transactions'),
            child: const Text('SEMUA'),
          ),
        ),
        const Hairline(),
        ...recent
            .take(5)
            .map((t) => _buildEditorialTransactionRow(t, ink, secondary)),
      ],
    );
  }

  Widget _buildEditorialTransactionRow(
    Map<String, dynamic> t,
    Color ink,
    Color secondary,
  ) {
    final isIncome = t['type'] == 'income';
    final amount = t['amount'] as num;
    final category = t['category'] as String? ?? 'Lainnya';
    final emoji = t['category_emoji'] as String? ?? '•';
    final date = DateFormat(
      'dd MMM',
      'id',
    ).format(DateFormat('yyyy-MM-dd').parse(t['date'] as String));
    final amountColor = isIncome
        ? ThemeUtils.getIncomeColor(context)
        : ThemeUtils.getExpenseColor(context);

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/transactions'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
              vertical: AppTheme.space20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        isIncome ? 'PEMASUKAN · $date' : 'PENGELUARAN · $date',
                        color: secondary,
                        size: 10,
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '−'} ${_money(amount)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Hairline(),
      ],
    );
  }
}

class _FeatureItem {
  final String eyebrow;
  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  _FeatureItem({
    required this.eyebrow,
    required this.label,
    required this.caption,
    required this.icon,
    required this.onTap,
  });
}

/// Editorial feature cell — hairline grid, eyebrow number + title + caption.
class _FeatureCell extends StatelessWidget {
  final _FeatureItem item;

  const _FeatureCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: hairline, width: AppTheme.hairlineWidth),
              bottom: BorderSide(
                color: hairline,
                width: AppTheme.hairlineWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.all(AppTheme.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Eyebrow(item.eyebrow, color: secondary, size: 10),
                  Icon(item.icon, size: 18, color: ink),
                ],
              ),
              const Spacer(),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: ink,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                item.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: secondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in the dashboard info dialog. Eyebrow (uppercase tracked) on
/// top with a short 14px accent bar, body paragraph below in muted ink.
/// Kept private to the dashboard since the styling is tailored to the
/// info-dialog layout.
class _InfoRow extends StatelessWidget {
  final Color ink;
  final Color accent;
  final String eyebrow;
  final String body;

  const _InfoRow({
    required this.ink,
    required this.accent,
    required this.eyebrow,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AccentBar(width: 14, height: 2, color: accent),
            const SizedBox(width: AppTheme.space8),
            Eyebrow(eyebrow, size: 10),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: ink,
          ),
        ),
      ],
    );
  }
}
