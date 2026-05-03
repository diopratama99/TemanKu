import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../services/notification_listener_service.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';

class NotificationReviewPage extends StatefulWidget {
  const NotificationReviewPage({super.key});

  @override
  State<NotificationReviewPage> createState() => _NotificationReviewPageState();
}

class _NotificationReviewPageState extends State<NotificationReviewPage> {
  bool _saving = false;

  void _finish() async {
    setState(() => _saving = true);
    await context.read<NotificationListenerService>().clearPendingReviews();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final service = context.read<NotificationListenerService>();
    final items = service.pendingReviews;

    if (items.isEmpty) {
      return Scaffold(backgroundColor: paper);
    }

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            EditorialHeader(
              eyebrow: 'REVIEW',
              title: 'Catatan\nOtomatis.',
              titleSize: 36,
              showBackButton: false, // Must finish to pop
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
                    'TemanKu mendeteksi dan mencatat aktivitas keuanganmu di latar belakang. Cek apakah datanya sudah benar.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: ThemeUtils.getTextSecondary(context),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),
                  for (int i = 0; i < items.length; i++) ...[
                    _buildReviewItem(items[i], i, items.length),
                    if (i < items.length - 1) ...[
                      const SizedBox(height: AppTheme.space24),
                      const Hairline(thickness: 2),
                      const SizedBox(height: AppTheme.space24),
                    ],
                  ],
                  const SizedBox(height: AppTheme.space40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _saving ? null : _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: ThemeUtils.getTextPrimary(context),
                        foregroundColor: paper,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'SELESAI',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
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

  Widget _buildReviewItem(Map<String, dynamic> item, int index, int total) {
    final action = item['action'] as String?;
    if (action == 'transfer') {
      return _buildTransferItem(item, index, total);
    }
    return _buildTransactionItem(item, index, total);
  }

  Widget _buildTransactionItem(Map<String, dynamic> item, int index, int total) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final isExpense = item['type'] == 'expense';
    final amountColor = isExpense
        ? (ThemeUtils.isDarkMode(context) ? AppTheme.darkExpenseColor : AppTheme.expenseColor)
        : (ThemeUtils.isDarkMode(context) ? AppTheme.darkIncomeColor : AppTheme.incomeColor);
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 1) ...[
          Eyebrow('TRANSAKSI ${index + 1} / $total', color: secondary),
          const SizedBox(height: AppTheme.space12),
        ],
        Text(
          isExpense ? 'PENGELUARAN' : 'PEMASUKAN',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: secondary,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          formatter.format(amount),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: amountColor,
            height: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        const Hairline(),
        _PreviewRow(label: 'AKUN', value: item['account'] ?? ''),
        _PreviewRow(
          label: 'TANGGAL',
          value: item['date'] ?? '',
        ),
        _PreviewRow(
          label: 'KETERANGAN',
          value: item['source_or_payee']?.toString().isEmpty ?? true ? '(kosong)' : item['source_or_payee'],
          muted: item['source_or_payee']?.toString().isEmpty ?? true,
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          'Edit data dari halaman detail transaksi atau riwayat.',
          style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: secondary),
        ),
        const SizedBox(height: AppTheme.space16),
        OutlinedButton.icon(
          onPressed: () async {
            final nav = Navigator.of(context);
            await context.read<NotificationListenerService>().clearPendingReviews();
            nav.pop();
            nav.pushNamed('/transactions');
          },
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Lihat Riwayat Transaksi'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ThemeUtils.getTextPrimary(context),
            side: BorderSide(color: ThemeUtils.getTextSecondary(context).withOpacity(0.3)),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferItem(Map<String, dynamic> item, int index, int total) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final amountColor = ThemeUtils.getTextPrimary(context);
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 1) ...[
          Eyebrow('MUTASI ${index + 1} / $total', color: secondary),
          const SizedBox(height: AppTheme.space12),
        ],
        Text(
          'MUTASI AKUN',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: secondary,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          formatter.format(amount),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: amountColor,
            height: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        const Hairline(),
        _PreviewRow(label: 'DARI', value: item['from_account'] ?? ''),
        _PreviewRow(label: 'KE', value: item['to_account'] ?? ''),
        _PreviewRow(label: 'TANGGAL', value: item['date'] ?? ''),
        const SizedBox(height: AppTheme.space16),
        OutlinedButton.icon(
          onPressed: () async {
            final nav = Navigator.of(context);
            await context.read<NotificationListenerService>().clearPendingReviews();
            nav.pop();
            nav.pushNamed('/accounts');
          },
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          label: const Text('Lihat Saldo Akun'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ThemeUtils.getTextPrimary(context),
            side: BorderSide(color: ThemeUtils.getTextSecondary(context).withOpacity(0.3)),
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;

  const _PreviewRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: secondary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: muted ? secondary : ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
