import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AuthNotifier>().logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final name = (user['name'] as String?) ?? 'User';
    final email = (user['email'] as String?) ?? '-';
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            EditorialHeader(
              eyebrow: 'COVER',
              title: 'Profil.',
              metaEyebrow: 'EDISI',
              meta: 'TEMANKU',
              titleSize: 36,
              showHairline: false,
            ),

            // User row with logout icon on the left
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pageGutter,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ThemeUtils.getCardColor(context),
                      border: Border.all(
                        color: ThemeUtils.isDarkMode(context)
                            ? AppTheme.darkHairlineColor
                            : AppTheme.hairlineColor,
                        width: AppTheme.hairlineWidth,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Center(
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space20),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('USER', color: secondary),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: ink,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  // Pure logout icon on the right
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 22,
                      color: AppTheme.expenseColor,
                    ),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            const Hairline(),

            // Menu rows
            _ProfileActionRow(
              eyebrow: 'PRIVASI',
              title: 'Data & Privasi',
              caption: 'Bagaimana datamu dikelola',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PrivacyPage()));
              },
            ),
            _ProfileActionRow(
              eyebrow: 'TENTANG',
              title: 'Tentang TemanKu',
              caption: 'Versi, tumpukan, dan kredit',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
              },
            ),

            const SizedBox(height: AppTheme.space40),
          ],
        ),
      ),
    );
  }
}

/// Editorial profile action row with hairline below.
class _ProfileActionRow extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? caption;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ProfileActionRow({
    required this.eyebrow,
    required this.title,
    this.caption,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final color = accentColor ?? ink;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                        Eyebrow(eyebrow, color: accentColor ?? secondary),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: color,
                          ),
                        ),
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
                  Icon(Icons.arrow_forward, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
        const Hairline(),
      ],
    );
  }
}

// =====================================================================
// Privacy page
// =====================================================================

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            EditorialHeader(
              eyebrow: 'PRIVASI',
              title: 'Privasi\n& data.',
              titleSize: 36,
              showBackButton: true,
              showHairline: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageGutter,
                  0,
                  AppTheme.pageGutter,
                  AppTheme.space40,
                ),
                children: [
                  Text(
                    'Catatanmu adalah milikmu. Kami menyimpan seminimal '
                    'mungkin dan tidak menjual datamu ke pihak ketiga.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),

                  _SectionTitle('YANG KAMU BERIKAN'),
                  _BulletList(
                    items: const [
                      'Email untuk masuk dan menerima email penting '
                          '(verifikasi, lupa sandi).',
                      'Username yang ditampilkan di dashboard.',
                      'Catatan transaksi: jumlah, kategori, tanggal, '
                          'akun, keterangan, dan catatan. Semua milikmu, '
                          'bisa diakses dan dihapus kapan saja.',
                      'Target tabungan, anggaran, dan mutasi antar '
                          'akun yang kamu buat sendiri.',
                    ],
                    ink: ink,
                    secondary: secondary,
                  ),

                  const SizedBox(height: AppTheme.space24),
                  _SectionTitle('DI MANA DISIMPAN'),
                  Text(
                    'Database Postgres di Supabase (region Asia Tenggara). '
                    'Semua koneksi melalui HTTPS. Setiap baris di-tag '
                    'dengan ID pengguna dan dilindungi Row Level Security, '
                    'jadi kamu hanya bisa membaca catatanmu sendiri.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: ink,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: AppTheme.space24),
                  _SectionTitle('YANG TIDAK KAMI LAKUKAN'),
                  _BulletList(
                    items: const [
                      'Tidak ada pelacakan iklan atau analitik pihak ketiga.',
                      'Tidak ada penjualan data.',
                      'Tidak ada pengiriman catatanmu ke layanan eksternal '
                          'tanpa pemicu langsung dari kamu.',
                    ],
                    ink: ink,
                    secondary: secondary,
                  ),

                  const SizedBox(height: AppTheme.space24),
                  _SectionTitle('HAK KAMU'),
                  _BulletList(
                    items: const [
                      'Edit atau hapus catatan kapan saja dari halaman Catatan.',
                      'Hapus akun dan semua data terkait. Tombolnya akan '
                          'segera tersedia, sementara ini bisa diminta lewat '
                          'kontak di bawah.',
                      'Minta salinan datamu dengan menghubungi developer.',
                    ],
                    ink: ink,
                    secondary: secondary,
                  ),

                  const SizedBox(height: AppTheme.space24),
                  _SectionTitle('KONTAK'),
                  Text(
                    'Pertanyaan, permintaan ekspor, atau penghapusan data: '
                    'hubungi TemanLabs lewat halaman Tentang TemanKu.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: ink,
                      height: 1.6,
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

// =====================================================================
// About page
// =====================================================================

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
            EditorialHeader(
              eyebrow: 'TENTANG',
              title: 'Tentang\nTemanKu.',
              titleSize: 36,
              showBackButton: true,
              showHairline: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageGutter,
                  0,
                  AppTheme.pageGutter,
                  AppTheme.space40,
                ),
                children: [
                  Text(
                    'Teman keuangan harian.',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    'Catat pengeluaran dan pemasukan harian, atur anggaran, '
                    'dan lacak target tabungan dengan tampilan tenang yang '
                    'mudah dibaca.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: AppTheme.space32),
                  _SectionTitle('DIBUAT OLEH'),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    decoration: BoxDecoration(
                      color: ThemeUtils.getCardColor(context),
                      border: Border.all(
                        color: ThemeUtils.isDarkMode(context)
                            ? AppTheme.darkHairlineColor
                            : AppTheme.hairlineColor,
                        width: AppTheme.hairlineWidth,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'TL',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TemanLabs',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                                Text(
                                  'Developer & maintainer',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.space12),
                        Text(
                          'Dibangun dengan tenang untuk siapa pun yang ingin '
                          'mengubah catatan harian menjadi keputusan keuangan '
                          'yang lebih baik.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: secondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.space32),
                  _SectionTitle('VERSI'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '0.1.0',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'rilis awal',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.space32),
                  _SectionTitle('TUMPUKAN'),
                  _StackRow(label: 'UI', value: 'Flutter'),
                  _StackRow(label: 'Backend & Auth', value: 'Supabase'),
                  _StackRow(label: 'Database', value: 'Postgres'),
                  _StackRow(label: 'Visualisasi', value: 'fl_chart'),

                  const SizedBox(height: AppTheme.space32),
                  _SectionTitle('TERIMA KASIH'),
                  Text(
                    'Untuk komunitas open source dan setiap orang yang sudah '
                    'mencoba TemanKu sejak hari pertama.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: AppTheme.space32),
                  Center(
                    child: Text(
                      '© 2026 TemanLabs',
                      style: GoogleFonts.inter(fontSize: 12, color: secondary),
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

// =====================================================================
// Helpers
// =====================================================================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Row(
        children: [
          Eyebrow(text, color: secondary),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Container(
              height: AppTheme.hairlineWidth,
              color: ThemeUtils.isDarkMode(context)
                  ? AppTheme.darkHairlineColor
                  : AppTheme.hairlineColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final Color ink;
  final Color secondary;
  const _BulletList({
    required this.items,
    required this.ink,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 6,
                    right: AppTheme.space12,
                  ),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: ink,
                      height: 1.6,
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

class _StackRow extends StatelessWidget {
  final String label;
  final String value;
  const _StackRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ThemeUtils.isDarkMode(context)
                ? AppTheme.darkHairlineColor
                : AppTheme.hairlineColor,
            width: AppTheme.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 14, color: secondary),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
