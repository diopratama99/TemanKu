import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import 'editorial.dart';

/// Editorial balance "page" — eyebrow BRANKAS + display number,
/// asymmetric two-column meta below, hairline rules.
class ModernBalanceCard extends StatelessWidget {
  final num balance;
  final num income;
  final num expense;
  final VoidCallback? onTap;

  const ModernBalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    this.onTap,
    super.key,
  });

  String _formatMoney(num value) {
    final formatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  String _formatPlain(num value) {
    final formatter = NumberFormat.currency(
      locale: 'id',
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(value).trim();
  }

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final incomeColor = ThemeUtils.getIncomeColor(context);
    final expenseColor = ThemeUtils.getExpenseColor(context);

    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pageGutter,
        vertical: AppTheme.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow row — BRANKAS · DETAIL ▸ (green accent — financial brand)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AccentBar(
                width: 24,
                height: 2,
                color: ThemeUtils.getAccentGreen(context),
              ),
              const SizedBox(width: AppTheme.space8),
              const Eyebrow('BRANKAS'),
              const Spacer(),
              if (onTap != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow('DETAIL', color: secondary),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: secondary),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),

          // Display amount — typography-first hero
          Text(
            'Saldo bersih bulan ini',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            _formatMoney(balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
              height: 1.0,
              color: ink,
            ),
          ),

          const SizedBox(height: AppTheme.space24),
          const Hairline(),
          const SizedBox(height: AppTheme.space20),

          // Asymmetric income / expense columns
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MoneyColumn(
                    label: 'PEMASUKAN',
                    amount: 'Rp ${_formatPlain(income)}',
                    color: incomeColor,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                const VerticalHairline(),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: _MoneyColumn(
                    label: 'PENGELUARAN',
                    amount: 'Rp ${_formatPlain(expense)}',
                    color: expenseColor,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}

class _MoneyColumn extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final CrossAxisAlignment alignment;

  const _MoneyColumn({
    required this.label,
    required this.amount,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.space16),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Eyebrow(label),
          const SizedBox(height: AppTheme.space8),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              height: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
