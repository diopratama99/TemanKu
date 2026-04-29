import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  String _typeFilter = 'expense';
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = context.read<AppDatabase>();
    final results = await db.getCategories(_typeFilter);
    setState(() => _categories = results);
  }

  Future<void> _addCategory() async {
    final result = await _showCategoryEditor(
      eyebrow: 'TULIS',
      title: _typeFilter == 'expense'
          ? 'Kategori pengeluaran baru'
          : 'Kategori pemasukan baru',
      onSubmit: (name, emoji) async {
        await context.read<AppDatabase>().insertCategory({
          'name': name,
          'emoji': emoji.isNotEmpty ? emoji : '📌',
          'type': _typeFilter,
        });
      },
    );

    if (result == true) {
      _loadCategories();
      if (!mounted) return;
      showSuccessSnackbar(context, 'Kategori berhasil ditambahkan');
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final id = category['id'] as int;
    final result = await _showCategoryEditor(
      eyebrow: 'SUNTING',
      title: 'Ubah ${category['name']}',
      initialName: category['name'] as String,
      initialEmoji: category['emoji'] as String? ?? '',
      onSubmit: (name, emoji) async {
        await context.read<AppDatabase>().updateCategory(id, {
          'name': name,
          'emoji': emoji.isNotEmpty ? emoji : '📌',
        });
      },
    );

    if (result == true) {
      _loadCategories();
      if (!mounted) return;
      showSuccessSnackbar(context, 'Kategori berhasil diperbarui');
    }
  }

  Future<bool?> _showCategoryEditor({
    required String eyebrow,
    required String title,
    String initialName = '',
    String initialEmoji = '',
    required Future<void> Function(String name, String emoji) onSubmit,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final emojiCtrl = TextEditingController(text: initialEmoji);
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space24,
            AppTheme.pageGutter,
            AppTheme.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AccentBar(width: 24, height: 2, color: ThemeUtils.getPrimaryColor(sheetContext)),
                  const SizedBox(width: AppTheme.space8),
                  Eyebrow(eyebrow, color: secondary),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              DisplayTitle(title, size: 24),
              const SizedBox(height: AppTheme.space24),
              const Hairline(),
              const SizedBox(height: AppTheme.space20),
              Eyebrow('EMOJI', color: secondary),
              const SizedBox(height: AppTheme.space8),
              TextField(
                controller: emojiCtrl,
                maxLength: 2,
                style: GoogleFonts.spaceGrotesk(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: '📌',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppTheme.space20),
              Eyebrow('NAMA', color: secondary),
              const SizedBox(height: AppTheme.space8),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: 'Misal: Makanan',
                ),
              ),
              const SizedBox(height: AppTheme.space32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      showErrorSnackbar(sheetContext, 'Nama kategori tidak boleh kosong');
                      return;
                    }
                    await onSubmit(nameCtrl.text.trim(), emojiCtrl.text.trim());
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext, true);
                  },
                  child: const Text('SIMPAN'),
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'BATAL',
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
      ),
    );
  }

  Future<void> _deleteCategory(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AppDatabase>().deleteCategory(id);
      _loadCategories();
      if (!mounted) return;
      showSuccessSnackbar(context, 'Kategori berhasil dihapus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final isExpense = _typeFilter == 'expense';

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorialHeader(
              eyebrow: 'INDEKS',
              title: 'Kategori.',
              metaEyebrow: 'JUMLAH',
              meta: '${_categories.length} item',
              titleSize: 36,
            ),
            // Type tabs (segmented underline)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pageGutter,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CategoryTab(
                      label: 'PENGELUARAN',
                      selected: isExpense,
                      onTap: () {
                        if (!isExpense) {
                          setState(() => _typeFilter = 'expense');
                          _loadCategories();
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _CategoryTab(
                      label: 'PEMASUKAN',
                      selected: !isExpense,
                      onTap: () {
                        if (isExpense) {
                          setState(() => _typeFilter = 'income');
                          _loadCategories();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            const Hairline(),

            // List
            Expanded(
              child: _categories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow('KOSONG', color: secondary),
                            const SizedBox(height: AppTheme.space12),
                            DisplayTitle(
                              isExpense
                                  ? 'Belum ada\nkategori pengeluaran.'
                                  : 'Belum ada\nkategori pemasukan.',
                              size: 24,
                            ),
                            const SizedBox(height: AppTheme.space12),
                            Text(
                              'Tambahkan kategori untuk mengorganisir transaksimu.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: secondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return _CategoryRow(
                          name: cat['name'] as String,
                          emoji: cat['emoji'] as String? ?? '📌',
                          onTap: () => _editCategory(cat),
                          onDelete: () => _deleteCategory(
                            cat['id'] as int,
                            cat['name'] as String,
                          ),
                        );
                      },
                    ),
            ),

            // Bottom add bar
            const Hairline(),
            Material(
              color: paper,
              child: InkWell(
                onTap: _addCategory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pageGutter,
                    vertical: AppTheme.space20,
                  ),
                  child: Row(
                    children: [
                      AccentBar(
                        width: 24,
                        height: 2,
                        color: ThemeUtils.getPrimaryColor(context),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Eyebrow('TAMBAH', color: secondary),
                      const Spacer(),
                      Text(
                        isExpense
                            ? 'Kategori pengeluaran'
                            : 'Kategori pemasukan',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Icon(Icons.add, size: 20, color: ink),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: selected ? ink : secondary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Container(
              height: 2,
              color: selected
                  ? ThemeUtils.getAccentGreen(context)
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final String emoji;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.name,
    required this.emoji,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

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
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 20, color: secondary),
                    splashRadius: 22,
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(Icons.chevron_right, size: 18, color: secondary),
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
