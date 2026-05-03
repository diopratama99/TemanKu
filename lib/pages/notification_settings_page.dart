import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/notification_listener_service.dart';
import '../services/notification_prefs_service.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';

/// Dedicated settings page for the notification auto-reader feature.
/// Explains what the feature does and provides two independent switches:
///   1. Auto account transfers (top-up, tarik tunai, transfer)
///   2. Auto add transactions (pembayaran)
///
/// Android-only. On iOS this page should not be reachable.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _prefs = NotificationPrefsService();
  bool _autoTransfer = false;
  bool _autoTransaction = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _prefs.autoTransferEnabled;
    final tx = await _prefs.autoTransactionEnabled;
    if (!mounted) return;
    setState(() {
      _autoTransfer = t;
      _autoTransaction = tx;
      _loading = false;
    });
  }

  Future<void> _openNotificationAccess() async {
    if (Platform.isAndroid) {
      // Open Android notification listener settings
      final channel = MethodChannel('temanku/notifications');
      try {
        await channel.invokeMethod('openNotificationSettings');
      } catch (_) {
        // Fallback: open app settings
        // ignore
      }
    }
  }

  Future<void> _checkPushPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final green = ThemeUtils.getAccentGreen(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: paper,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            EditorialHeader(
              eyebrow: 'OTOMATIS',
              title: 'Baca\nNotifikasi.',
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
                  // Intro
                  Text(
                    'TemanKu bisa membaca notifikasi dari aplikasi '
                    'keuanganmu (GoPay, OVO, DANA, BCA, dll) lalu '
                    'mencatat transaksi dan mutasi akun secara otomatis.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),

                  // How it works
                  _SectionTitle('CARA KERJA'),
                  _StepRow(
                    number: '01',
                    title: 'Notifikasi masuk',
                    body:
                        'Saat kamu bayar, top-up, atau transfer, '
                        'aplikasi keuanganmu mengirim notifikasi.',
                    ink: ink,
                    secondary: secondary,
                  ),
                  _StepRow(
                    number: '02',
                    title: 'AI membaca',
                    body:
                        'Teks notifikasi dikirim ke AI untuk '
                        'dikenali seperti jumlah, tujuan, dan jenis transaksi.',
                    ink: ink,
                    secondary: secondary,
                  ),
                  _StepRow(
                    number: '03',
                    title: 'Otomatis tercatat',
                    body:
                        'Transaksi atau mutasi akun langsung '
                        'masuk ke catatan TemanKu tanpa kamu ketik apa pun.',
                    ink: ink,
                    secondary: secondary,
                  ),

                  const SizedBox(height: AppTheme.space24),

                  // Security info
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: green),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Text(
                            'Notifikasi dibaca secara lokal di perangkatmu. '
                            'Hanya teks dari aplikasi keuangan yang dikirim '
                            'ke AI untuk diproses. Notifikasi lain (WhatsApp, '
                            'SMS, dll) tidak pernah dibaca.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: secondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.space32),

                  // Switches
                  _SectionTitle('PENGATURAN'),

                  // Switch 1: Auto Transfer
                  _SwitchRow(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Auto Mutasi Akun',
                    caption:
                        'Otomatis catat top-up, tarik tunai, dan '
                        'transfer antar akun (Tunai ↔ Transfer ↔ E-Wallet)',
                    value: _autoTransfer,
                    ink: ink,
                    secondary: secondary,
                    green: green,
                    onChanged: (v) async {
                      if (v) await _checkPushPermission();
                      setState(() => _autoTransfer = v);
                      await _prefs.setAutoTransfer(v);
                    },
                  ),

                  const SizedBox(height: AppTheme.space4),

                  // Switch 2: Auto Transaction
                  _SwitchRow(
                    icon: Icons.receipt_long_rounded,
                    title: 'Auto Tambah Transaksi',
                    caption:
                        'Otomatis catat pembayaran dan pembelian '
                        'ke riwayat transaksi',
                    value: _autoTransaction,
                    ink: ink,
                    secondary: secondary,
                    green: green,
                    onChanged: (v) async {
                      if (v) await _checkPushPermission();
                      setState(() => _autoTransaction = v);
                      await _prefs.setAutoTransaction(v);
                    },
                  ),

                  const SizedBox(height: AppTheme.space32),

                  // Notification access button
                  _SectionTitle('AKSES NOTIFIKASI'),
                  Text(
                    'Untuk menggunakan fitur ini, TemanKu perlu '
                    'izin membaca notifikasi. Buka pengaturan '
                    'perangkat untuk mengaktifkannya.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: secondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  OutlinedButton.icon(
                    onPressed: _openNotificationAccess,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('BUKA PENGATURAN AKSES NOTIFIKASI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space20,
                        vertical: AppTheme.space16,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.space32),

                  // Supported apps
                  _SectionTitle('APLIKASI YANG DIDUKUNG'),
                  Wrap(
                    spacing: AppTheme.space8,
                    runSpacing: AppTheme.space8,
                    children: const [
                      _AppChip('GoPay'),
                      _AppChip('OVO'),
                      _AppChip('DANA'),
                      _AppChip('ShopeePay'),
                      _AppChip('LinkAja'),
                      _AppChip('BCA'),
                      _AppChip('BRI'),
                      _AppChip('Mandiri'),
                      _AppChip('BNI'),
                      _AppChip('Wondr BNI'),
                      _AppChip('Permata'),
                      _AppChip('CIMB Niaga'),
                      _AppChip('Bank Jago'),
                      _AppChip('SeaBank'),
                      _AppChip('Jenius'),
                      _AppChip('blu BCA'),
                      _AppChip('Neobank'),
                      _AppChip('Allo Bank'),
                      _AppChip('Superbank'),
                    ],
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

// ─── Helper Widgets ──────────────────────────────────────────────────────

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

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final Color ink;
  final Color secondary;

  const _StepRow({
    required this.number,
    required this.title,
    required this.body,
    required this.ink,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              number,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: ThemeUtils.isDarkMode(context)
                    ? AppTheme.darkHairlineColor
                    : AppTheme.hairlineColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: secondary,
                    height: 1.5,
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

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final bool value;
  final Color ink;
  final Color secondary;
  final Color green;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.caption,
    required this.value,
    required this.ink,
    required this.secondary,
    required this.green,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: ThemeUtils.getCardColor(context),
        border: Border.all(
          color: value
              ? green.withValues(alpha: 0.4)
              : (ThemeUtils.isDarkMode(context)
                    ? AppTheme.darkHairlineColor
                    : AppTheme.hairlineColor),
          width: value ? 1.5 : AppTheme.hairlineWidth,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: value ? green : secondary),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  caption,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: secondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Switch.adaptive(
            value: value,
            activeColor: green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  final String label;
  const _AppChip(this.label);

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: ThemeUtils.isDarkMode(context)
              ? AppTheme.darkHairlineColor
              : AppTheme.hairlineColor,
          width: AppTheme.hairlineWidth,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
      ),
    );
  }
}
