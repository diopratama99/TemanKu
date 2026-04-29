import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import 'editorial.dart';

/// One label/value row in the draft preview.
class TransactionPreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool muted;

  const TransactionPreviewRow({
    required this.label,
    required this.value,
    this.onTap,
    this.muted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final valueColor = muted ? secondary : ink;
    return InkWell(
      onTap: onTap,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: secondary,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                  letterSpacing: -0.2,
                  fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppTheme.space8),
              Icon(Icons.edit, size: 14, color: secondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet of mutually-exclusive choices (e.g. expense/income, account).
class TransactionChoiceSheet extends StatelessWidget {
  final String title;
  final String current;
  final List<(String, String)> choices;
  final ValueChanged<String> onSelected;

  const TransactionChoiceSheet({
    required this.title,
    required this.current,
    required this.choices,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.pageGutter,
          vertical: AppTheme.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Eyebrow(title, color: secondary),
            const SizedBox(height: AppTheme.space12),
            for (final c in choices)
              InkWell(
                onTap: () {
                  onSelected(c.$1);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space16,
                  ),
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
                          c.$2,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      if (c.$1 == current)
                        Icon(Icons.check, size: 18, color: accent),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draggable scrollable sheet listing categories.
class TransactionCategoryPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int currentId;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const TransactionCategoryPickerSheet({
    required this.categories,
    required this.currentId,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageGutter,
                  AppTheme.space24,
                  AppTheme.pageGutter,
                  AppTheme.space12,
                ),
                child: Row(
                  children: [Eyebrow('PILIH KATEGORI', color: secondary)],
                ),
              ),
              const Hairline(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    final isSelected = cat['id'] == currentId;
                    return InkWell(
                      onTap: () {
                        onSelected(cat);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.pageGutter,
                          vertical: AppTheme.space16,
                        ),
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
                            if ((cat['emoji'] as String?)?.isNotEmpty ??
                                false) ...[
                              Text(
                                cat['emoji'] as String,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: AppTheme.space12),
                            ],
                            Expanded(
                              child: Text(
                                cat['name'] as String,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check, size: 18, color: accent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small confidence pill used in draft headers.
class TransactionConfidenceBadge extends StatelessWidget {
  final String level; // "high" | "medium" | "low"
  const TransactionConfidenceBadge({required this.level, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeUtils.isDarkMode(context);
    Color color;
    String text;
    switch (level) {
      case 'high':
        color = isDark ? AppTheme.darkIncomeColor : AppTheme.incomeColor;
        text = 'YAKIN';
        break;
      case 'low':
        color = isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor;
        text = 'CEK ULANG';
        break;
      default:
        color = ThemeUtils.getTextSecondary(context);
        text = 'CUKUP YAKIN';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: color,
        ),
      ),
    );
  }
}

/// Modal bottom-sheet text editor used by both voice and OCR draft previews.
Future<String?> showTransactionTextEditor(
  BuildContext context, {
  required String title,
  required String initialValue,
  String? hint,
  TextInputType keyboardType = TextInputType.text,
  bool multiline = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  final ink = ThemeUtils.getTextPrimary(context);
  final secondary = ThemeUtils.getTextSecondary(context);
  final paper = ThemeUtils.getBackgroundColor(context);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: paper,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: AppTheme.pageGutter,
          right: AppTheme.pageGutter,
          top: AppTheme.space24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(title, color: secondary),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboardType,
              maxLines: multiline ? 4 : 1,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                color: ink,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(fontSize: 14, color: secondary),
                border: const UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'BATAL',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: secondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(controller.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: paper,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space20,
                      vertical: AppTheme.space12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall,
                      ),
                    ),
                  ),
                  child: Text(
                    'SIMPAN',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
