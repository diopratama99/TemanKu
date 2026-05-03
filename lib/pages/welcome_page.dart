import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import 'home_page.dart';

/// Editorial onboarding for new users. Light cream paper theme with
/// indigo accent and forest-green masthead, matching the rest of TemanKu.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  static const String _prefsPrefix = 'welcome_seen_';

  static String _keyFor(String? userId) => '$_prefsPrefix${userId ?? "anon"}';

  static Future<bool> hasSeen(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(userId)) ?? false;
  }

  static Future<void> markSeen(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(userId), true);
  }

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _controller = PageController();
  int _index = 0;

  late final List<_OnboardData> _pages = [
    _OnboardData(
      eyebrow: 'EDISI 01',
      title: 'Hai,\nselamat datang.',
      description:
          'TemanKu adalah teman keuangan harianmu. Catat sekali, '
          'lihat polanya, dan rencanakan dengan tenang.',
      illustration: const _LogoIllustration(),
    ),
    _OnboardData(
      eyebrow: 'EDISI 02',
      title: 'Catat\ntransaksi\nharian.',
      description:
          'Tulis pengeluaran dan pemasukan dengan kategori, akun, '
          'dan keterangan yang rapi. Cepat saat dibutuhkan.',
      illustration: const _NoteIllustration(),
    ),
    _OnboardData(
      eyebrow: 'EDISI 03',
      title: 'Atur\nanggaran\n& target.',
      description:
          'Tetapkan batas pengeluaran per kategori dan target '
          'tabungan jangka panjang. Pantau progresnya.',
      illustration: const _BudgetIllustration(),
    ),
    _OnboardData(
      eyebrow: 'EDISI 04',
      title: 'Lihat\ntren bulanan.',
      description:
          'Pahami pola keuanganmu lewat grafik dan perbandingan '
          'antar bulan secara otomatis.',
      illustration: const _TrendIllustration(),
    ),
    _OnboardData(
      eyebrow: 'EDISI 05',
      title: 'Mulai\nhari ini.',
      description:
          'Mulai dari satu transaksi. Hari demi hari kamu akan '
          'punya gambaran utuh tentang keuanganmu.',
      illustration: const _StartIllustration(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    final auth = context.read<AuthNotifier>();
    await WelcomePage.markSeen(auth.userId);
    if (!mounted) return;
    final isLoggedIn = auth.isLoggedIn;
    if (isLoggedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String _counter(int i) {
    final cur = (i + 1).toString().padLeft(2, '0');
    final total = _pages.length.toString().padLeft(2, '0');
    return '$cur / $total';
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: counter + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageGutter,
                AppTheme.space16,
                AppTheme.pageGutter,
                AppTheme.space8,
              ),
              child: Row(
                children: [
                  Text(
                    _counter(_index),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: secondary,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLast)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _finish,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space8,
                          vertical: AppTheme.space4,
                        ),
                        child: Text(
                          'LEWATI',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.6,
                            color: secondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _OnboardPanel(
                  data: _pages[i],
                  ink: ink,
                  secondary: secondary,
                  accent: accent,
                ),
              ),
            ),

            // Bottom: dots + CTA
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.pageGutter,
                AppTheme.space16,
                AppTheme.pageGutter,
                MediaQuery.of(context).padding.bottom + AppTheme.space24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final selected = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        height: 2,
                        width: selected ? 28 : 14,
                        decoration: BoxDecoration(
                          color: selected
                              ? accent
                              : (ThemeUtils.isDarkMode(context)
                                    ? AppTheme.darkHairlineColor
                                    : AppTheme.hairlineColor),
                        ),
                      );
                    }),
                  ),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: paper,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isLast ? 'MULAI' : 'LANJUT',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardData {
  final String eyebrow;
  final String title;
  final String description;
  final Widget illustration;
  const _OnboardData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.illustration,
  });
}

class _OnboardPanel extends StatelessWidget {
  final _OnboardData data;
  final Color ink;
  final Color secondary;
  final Color accent;

  const _OnboardPanel({
    required this.data,
    required this.ink,
    required this.secondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.space24),
          Row(
            children: [
              AccentBar(width: 24, height: 2, color: accent),
              const SizedBox(width: AppTheme.space8),
              Eyebrow(data.eyebrow, color: secondary),
            ],
          ),
          const SizedBox(height: AppTheme.space32),

          // Illustration centered with surrounding paper
          Center(
            child: SizedBox(
              height: 220,
              child: Center(child: data.illustration),
            ),
          ),

          const SizedBox(height: AppTheme.space40),
          const Hairline(),
          const SizedBox(height: AppTheme.space24),

          Text(
            data.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              height: 1.05,
              color: ink,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            data.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: secondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppTheme.space24),
        ],
      ),
    );
  }
}

// =====================================================================
// Illustrations — editorial paper style with thin lines and indigo accent
// =====================================================================

class _LogoIllustration extends StatelessWidget {
  const _LogoIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Image.asset(
          'assets/images/temanku_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _NoteIllustration extends StatelessWidget {
  const _NoteIllustration();

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        children: [
          // Background card
          Positioned(
            right: 0,
            top: 8,
            child: Container(
              width: 170,
              height: 110,
              decoration: BoxDecoration(
                color: ThemeUtils.getCardColor(context),
                border: Border.all(color: hairline),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          ),
          // Foreground card
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 200,
              height: 140,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThemeUtils.getBackgroundColor(context),
                border: Border.all(color: ink, width: 1.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 16, height: 2, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'PENGELUARAN',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rp 45.000',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(width: 140, height: 1, color: hairline),
                  const SizedBox(height: 10),
                  Text(
                    'Makan siang',
                    style: GoogleFonts.inter(fontSize: 11, color: ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '29 Apr 2026',
                    style: GoogleFonts.inter(fontSize: 10, color: secondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetIllustration extends StatelessWidget {
  const _BudgetIllustration();

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ThemeUtils.getBackgroundColor(context),
        border: Border.all(color: ink, width: 1.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 16, height: 2, color: accent),
              const SizedBox(width: 6),
              Text(
                'ANGGARAN',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Rp 2.500.000',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),
          _row(
            label: 'Makan',
            progress: 0.7,
            ink: ink,
            secondary: secondary,
            hairline: hairline,
            accent: accent,
          ),
          const SizedBox(height: 10),
          _row(
            label: 'Transport',
            progress: 0.45,
            ink: ink,
            secondary: secondary,
            hairline: hairline,
            accent: accent,
          ),
          const SizedBox(height: 10),
          _row(
            label: 'Belanja',
            progress: 0.3,
            ink: ink,
            secondary: secondary,
            hairline: hairline,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String label,
    required double progress,
    required Color ink,
    required Color secondary,
    required Color hairline,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: ink)),
            const Spacer(),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 2,
          color: hairline,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(color: accent),
          ),
        ),
      ],
    );
  }
}

class _TrendIllustration extends StatelessWidget {
  const _TrendIllustration();

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ThemeUtils.getBackgroundColor(context),
        border: Border.all(color: ink, width: 1.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 16, height: 2, color: accent),
              const SizedBox(width: 6),
              Text(
                'TREN',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '6 bulan terakhir',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _TrendPainter(line: ink, accent: accent, grid: hairline),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final Color line;
  final Color accent;
  final Color grid;
  _TrendPainter({required this.line, required this.accent, required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final values = [0.55, 0.4, 0.7, 0.5, 0.85, 0.65];
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = accent;
    final dotEdge = Paint()
      ..color = line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - values[i]);
      canvas.drawCircle(Offset(x, y), 3.5, dotFill);
      canvas.drawCircle(Offset(x, y), 3.5, dotEdge);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StartIllustration extends StatelessWidget {
  const _StartIllustration();

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            border: Border.all(color: ink, width: 1.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
                child: Container(width: 20, height: 2, color: accent),
              ),
              Center(
                child: Text(
                  '01',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -2.0,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  'TRANSAKSI',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 1.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            'SIAP MULAI',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}
