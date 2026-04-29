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
  // Currency selector removed - app uses IDR only

  @override
  void initState() {
    super.initState();
  }

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
    final name = user['name'] as String?;
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

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

            // Editorial profile slab
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pageGutter,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        (name ?? 'U').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space20),
                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.space4),
                        Eyebrow('PEMEGANG', color: secondary),
                        const SizedBox(height: AppTheme.space8),
                        DisplayTitle(
                          name ?? 'User',
                          size: 26,
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          '@${user['username'] as String? ?? '-'}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            const Hairline(),

            // Logout row
            _ProfileActionRow(
              eyebrow: 'KELUAR',
              title: 'Logout dari Temanku',
              caption: 'Akhiri sesi pengguna',
              accentColor: AppTheme.expenseColor,
              onTap: _logout,
            ),

            const SizedBox(height: AppTheme.space40),

            // Colophon
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pageGutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AccentBar(width: 24, height: 2, color: accent),
                      const SizedBox(width: AppTheme.space8),
                      Eyebrow('KOLOFON', color: secondary),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space12),
                  Text(
                    'Temanku',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'Diterbitkan TemanLabs · Versi 1.5.1',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space40),
          ],
        ),
      ),
    );
  }
}

/// Editorial profile action row — hairline above + below.
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


