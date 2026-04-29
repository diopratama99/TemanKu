import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import 'editorial.dart';

/// Editorial transaction row — magazine listing entry.
///
/// Layout (asymmetric, baseline-aligned):
///   [emoji]  CATEGORY · ACCOUNT          AMOUNT
///            dd MMM yyyy · notes        (income / expense)
/// followed by a 1px hairline rule.
class TransactionListTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const TransactionListTile({
    required this.transaction,
    required this.onTap,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction['type'] == 'income';
    final amount = transaction['amount'] as num;
    final category = transaction['category'] as String? ?? 'Tanpa Kategori';
    final date = transaction['date'] as String;
    final emoji = transaction['category_emoji'] as String? ?? '•';
    final account = transaction['account'] as String? ?? '-';
    final notes = transaction['notes'] as String? ?? '';

    final money = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final formattedDate = DateFormat(
      'dd MMM yyyy',
      'id',
    ).format(DateFormat('yyyy-MM-dd').parse(date));

    final semanticLabel =
        '${isIncome ? 'Pemasukan' : 'Pengeluaran'} '
        '${money.format(amount)}, kategori $category, '
        'tanggal $formattedDate, metode pembayaran $account';

    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final amountColor = isIncome
        ? ThemeUtils.getIncomeColor(context)
        : ThemeUtils.getExpenseColor(context);

    Widget row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.pageGutter,
          vertical: AppTheme.space20,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glyph — restrained square slot
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space16),

            // Title column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    isIncome ? 'PEMASUKAN' : 'PENGELUARAN',
                    color: amountColor,
                    size: 10,
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    notes.isEmpty
                        ? '$formattedDate · $account'
                        : '$formattedDate · $account · $notes',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.5,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.space12),

            // Amount column — baseline aligned with title
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Eyebrow(
                  isIncome ? 'MASUK' : 'KELUAR',
                  color: secondary,
                  size: 10,
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  '${isIncome ? '+' : '−'} ${money.format(amount)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    Widget listItem = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const Hairline(),
      ],
    );

    if (onDelete != null) {
      listItem = Dismissible(
        key: ValueKey(transaction['id']),
        direction: DismissDirection.endToStart,
        background: Container(
          color: ThemeUtils.getExpenseColor(context).withOpacity(0.08),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppTheme.pageGutter),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: ThemeUtils.getExpenseColor(context), size: 20),
              const SizedBox(width: AppTheme.space8),
              Text(
                'HAPUS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: ThemeUtils.getExpenseColor(context),
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Transaksi?'),
                  content: Text(
                    'Apakah Anda yakin ingin menghapus transaksi '
                    '$category sebesar ${money.format(amount)}? '
                    'Tindakan ini tidak dapat dibatalkan.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('BATAL'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: ThemeUtils.getExpenseColor(context),
                      ),
                      child: const Text('HAPUS'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        onDismissed: (_) => onDelete!(),
        child: listItem,
      );
    }

    return Semantics(label: semanticLabel, button: true, child: listItem);
  }
}

/// Compact transaction card for mobile grid view — editorial flat slab.
class TransactionCompactCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;

  const TransactionCompactCard({
    required this.transaction,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction['type'] == 'income';
    final amount = transaction['amount'] as num;
    final category = transaction['category'] as String? ?? '-';
    final emoji = transaction['category_emoji'] as String? ?? '•';

    final money = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return EditorialCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: AppTheme.space12),
          Text(
            category,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: ThemeUtils.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            '${isIncome ? '+' : '−'}${money.format(amount)}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isIncome
                  ? ThemeUtils.getIncomeColor(context)
                  : ThemeUtils.getExpenseColor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
