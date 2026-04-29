import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../models/parsed_transaction.dart';
import '../services/receipt_ocr_service.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';
import '../widgets/transaction_draft_widgets.dart';

/// Phases the receipt OCR flow can be in.
enum _Phase { idle, uploading, preview, error }

/// Editorial OCR composer — magazine "STRUK" page.
///
/// User picks a receipt photo (camera or gallery), the app sends it to the
/// `parse-receipt` Supabase Edge Function (GPT-4o vision), and the returned
/// drafts land in an editable preview that mirrors the voice flow.
class ReceiptOcrPage extends StatefulWidget {
  const ReceiptOcrPage({super.key});

  @override
  State<ReceiptOcrPage> createState() => _ReceiptOcrPageState();
}

class _ReceiptOcrPageState extends State<ReceiptOcrPage> {
  final ImagePicker _picker = ImagePicker();
  final ReceiptOcrService _ocr = ReceiptOcrService();

  _Phase _phase = _Phase.idle;
  String _errorMessage = '';
  Uint8List? _imageBytes;
  String _mime = 'image/jpeg';
  String _summary = '';
  final List<TransactionDraft> _drafts = [];
  bool _saving = false;

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // Compress aggressively client-side so the edge function payload
        // stays well under its hard cap and round-trip stays snappy.
        imageQuality: 78,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return; // user cancelled
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _mime = _guessMime(picked.name);
        _phase = _Phase.uploading;
        _errorMessage = '';
        _drafts.clear();
        _summary = '';
      });
      await _runOcr();
    } catch (e) {
      _setError('Gagal mengambil foto: $e');
    }
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _runOcr() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    try {
      final result = await _ocr.parseImage(bytes, mime: _mime);
      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(result.drafts.map(TransactionDraft.fromParsed));
        _summary = result.transcript;
        _phase = _Phase.preview;
      });
    } on ReceiptOcrException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Tidak terhubung: $e');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorMessage = msg;
    });
  }

  Future<void> _save() async {
    if (_drafts.isEmpty) return;
    setState(() => _saving = true);
    final db = context.read<AppDatabase>();
    try {
      for (final d in _drafts) {
        await db.insertTransaction(d.toInsertPayload());
      }
      if (!mounted) return;
      final count = _drafts.length;
      Navigator.of(context).pop(true);
      showSuccessSnackbar(
        context,
        count == 1 ? 'Transaksi tersimpan' : '$count transaksi tersimpan',
      );
    } catch (e) {
      _setError('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _removeDraft(int index) {
    if (index < 0 || index >= _drafts.length) return;
    setState(() {
      _drafts.removeAt(index);
      if (_drafts.isEmpty) {
        _phase = _Phase.idle;
        _imageBytes = null;
        _summary = '';
      }
    });
  }

  void _reset() {
    setState(() {
      _phase = _Phase.idle;
      _errorMessage = '';
      _imageBytes = null;
      _summary = '';
      _drafts.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            const EditorialHeader(
              eyebrow: 'STRUK',
              title: 'Foto saja,\nkami yang baca.',
              titleSize: 36,
              showBackButton: true,
              showHairline: false,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.idle:
        return _buildIdle();
      case _Phase.uploading:
        return _buildLoading('Sedang membaca strukmu...');
      case _Phase.preview:
        return _buildPreview();
      case _Phase.error:
        return _buildError();
    }
  }

  // ────────────── IDLE UI ──────────────

  Widget _buildIdle() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final paper = ThemeUtils.getBackgroundColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.space16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AccentBar(width: 24, height: 2, color: accent),
                      const SizedBox(width: AppTheme.space8),
                      Eyebrow('CARA PAKAI', color: secondary),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  _buildHowToStep(
                    n: '01',
                    title: 'Foto struk',
                    body:
                        'Letakkan struk di permukaan datar dengan pencahayaan baik.',
                    ink: ink,
                    secondary: secondary,
                  ),
                  _buildHowToStep(
                    n: '02',
                    title: 'TemanKu membaca',
                    body:
                        'Total, tanggal, dan toko diekstrak otomatis lewat AI.',
                    ink: ink,
                    secondary: secondary,
                  ),
                  _buildHowToStep(
                    n: '03',
                    title: 'Cek dan simpan',
                    body:
                        'Tap apa pun untuk mengubahnya, lalu tekan SIMPAN.',
                    ink: ink,
                    secondary: secondary,
                    isLast: true,
                  ),
                  const SizedBox(height: AppTheme.space24),
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
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: secondary),
                        const SizedBox(width: AppTheme.space8),
                        Expanded(
                          child: Text(
                            'Foto strukmu dikirim ke layanan AI untuk dibaca. '
                            'Data lain tidak ikut terkirim.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: secondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons.
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.space16,
              bottom: AppTheme.space24,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _pickFrom(ImageSource.camera),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(
                      'AMBIL FOTO STRUK',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                TextButton.icon(
                  onPressed: () => _pickFrom(ImageSource.gallery),
                  icon: Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: secondary,
                  ),
                  label: Text(
                    'PILIH DARI GALERI',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToStep({
    required String n,
    required String title,
    required String body,
    required Color ink,
    required Color secondary,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              n,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.5,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
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

  // ────────────── PREVIEW UI ──────────────

  Widget _buildPreview() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final paper = ThemeUtils.getBackgroundColor(context);

    final total = _drafts.length;
    final isMulti = total > 1;

    final saveLabel = total == 1 ? 'SIMPAN' : 'SIMPAN $total';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageGutter,
        0,
        AppTheme.pageGutter,
        AppTheme.space40,
      ),
      children: [
        // Top bar: DRAFT label
        Row(
          children: [
            AccentBar(width: 24, height: 2, color: accent),
            const SizedBox(width: AppTheme.space8),
            Eyebrow(
              isMulti ? 'DRAFT — $total TRANSAKSI' : 'DRAFT',
              color: secondary,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          isMulti
              ? 'Tap apa pun untuk mengubahnya. Tekan × untuk hapus salah satu.'
              : 'Tap apa pun untuk mengubahnya',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: secondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppTheme.space24),

        // Receipt thumbnail.
        if (_imageBytes != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.space24),
            decoration: BoxDecoration(
              border: Border.all(
                color: ThemeUtils.isDarkMode(context)
                    ? AppTheme.darkHairlineColor
                    : AppTheme.hairlineColor,
                width: AppTheme.hairlineWidth,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),

        // One section per draft
        for (int i = 0; i < total; i++) ...[
          _buildDraftSection(i, _drafts[i], total),
          if (i < total - 1) ...[
            const SizedBox(height: AppTheme.space24),
            const Hairline(thickness: 2),
            const SizedBox(height: AppTheme.space24),
          ],
        ],

        const SizedBox(height: AppTheme.space24),

        if (_summary.isNotEmpty)
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
                Eyebrow('RINGKASAN STRUK', color: secondary),
                const SizedBox(height: AppTheme.space8),
                Text(
                  _summary,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    color: ink,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppTheme.space32),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _reset,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: ThemeUtils.isDarkMode(context)
                        ? AppTheme.darkHairlineColor
                        : AppTheme.hairlineColor,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  foregroundColor: ink,
                ),
                child: Text(
                  'ULANGI',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: paper,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            saveLabel,
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
      ],
    );
  }

  Widget _buildDraftSection(int index, TransactionDraft d, int total) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final isExpense = d.type == 'expense';
    final amountColor = isExpense
        ? (ThemeUtils.isDarkMode(context)
              ? AppTheme.darkExpenseColor
              : AppTheme.expenseColor)
        : (ThemeUtils.isDarkMode(context)
              ? AppTheme.darkIncomeColor
              : AppTheme.incomeColor);
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isMulti = total > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMulti) ...[
          Row(
            children: [
              Eyebrow('TRANSAKSI ${index + 1} / $total', color: secondary),
              const Spacer(),
              TransactionConfidenceBadge(level: d.confidence),
              const SizedBox(width: AppTheme.space8),
              InkWell(
                onTap: () => _confirmRemoveDraft(index),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
        ] else ...[
          Row(
            children: [
              const Spacer(),
              TransactionConfidenceBadge(level: d.confidence),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
        ],

        // Type
        InkWell(
          onTap: () => _editType(d),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
            child: Row(
              children: [
                Text(
                  isExpense ? 'PENGELUARAN' : 'PEMASUKAN',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: secondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit, size: 12, color: secondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space8),

        // Amount
        InkWell(
          onTap: () => _editAmount(d),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    formatter.format(d.amount),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: isMulti ? 34 : 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: amountColor,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Icon(Icons.edit, size: 14, color: secondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        const Hairline(),

        // Fields
        TransactionPreviewRow(
          label: 'KATEGORI',
          value:
              '${d.categoryEmoji != null ? '${d.categoryEmoji} ' : ''}${d.categoryName}',
          onTap: () => _editCategory(d),
        ),
        TransactionPreviewRow(
          label: 'AKUN',
          value: d.account,
          onTap: () => _editAccount(d),
        ),
        TransactionPreviewRow(
          label: 'TANGGAL',
          value: DateFormat('d MMMM yyyy', 'id_ID').format(d.date),
          onTap: () => _editDate(d),
        ),
        TransactionPreviewRow(
          label: 'KETERANGAN',
          value: d.sourceOrPayee.isEmpty ? '(kosong)' : d.sourceOrPayee,
          muted: d.sourceOrPayee.isEmpty,
          onTap: () => _editKeterangan(d),
        ),
        TransactionPreviewRow(
          label: 'CATATAN',
          value: d.notes.isEmpty ? '(kosong)' : d.notes,
          muted: d.notes.isEmpty,
          onTap: () => _editCatatan(d),
        ),

        if (d.reasoning.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space16),
          Eyebrow('CARA TEMANKU MEMBACA', color: secondary),
          const SizedBox(height: AppTheme.space8),
          Text(
            d.reasoning,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondary,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRemoveDraft(int index) async {
    if (_drafts.length <= 1) {
      _reset();
      return;
    }
    _removeDraft(index);
  }

  // ────────────── EDIT HANDLERS ──────────────

  void _editType(TransactionDraft d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeUtils.getBackgroundColor(context),
      builder: (ctx) => TransactionChoiceSheet(
        title: 'JENIS TRANSAKSI',
        current: d.type,
        choices: const [('expense', 'Pengeluaran'), ('income', 'Pemasukan')],
        onSelected: (v) async {
          if (v == d.type) return;
          try {
            final cats = await context.read<AppDatabase>().getCategories(v);
            if (!mounted) return;
            setState(() {
              d.type = v;
              if (cats.isNotEmpty) {
                d.categoryId = cats.first['id'] as int;
                d.categoryName = cats.first['name'] as String;
                d.categoryEmoji = cats.first['emoji'] as String?;
              }
            });
          } catch (_) {
            if (!mounted) return;
            setState(() => d.type = v);
          }
        },
      ),
    );
  }

  Future<void> _editAmount(TransactionDraft d) async {
    final newValue = await showTransactionTextEditor(
      context,
      title: 'JUMLAH (Rp)',
      initialValue: d.amount == 0 ? '' : d.amount.toString(),
      keyboardType: TextInputType.number,
      hint: 'mis. 47500',
    );
    if (newValue == null) return;
    final clean = newValue.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean);
    if (parsed == null) return;
    setState(() => d.amount = parsed);
  }

  Future<void> _editCategory(TransactionDraft d) async {
    try {
      final cats = await context.read<AppDatabase>().getCategories(d.type);
      if (!mounted || cats.isEmpty) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: ThemeUtils.getBackgroundColor(context),
        isScrollControlled: true,
        builder: (ctx) => TransactionCategoryPickerSheet(
          categories: cats,
          currentId: d.categoryId,
          onSelected: (cat) {
            setState(() {
              d.categoryId = cat['id'] as int;
              d.categoryName = cat['name'] as String;
              d.categoryEmoji = cat['emoji'] as String?;
            });
          },
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Gagal memuat kategori: $e');
    }
  }

  void _editAccount(TransactionDraft d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeUtils.getBackgroundColor(context),
      builder: (ctx) => TransactionChoiceSheet(
        title: 'AKUN',
        current: d.account,
        choices: const [
          ('Tunai', 'Tunai'),
          ('Transfer', 'Transfer / Rekening'),
          ('E-Wallet', 'E-Wallet'),
        ],
        onSelected: (v) {
          setState(() => d.account = v);
        },
      ),
    );
  }

  Future<void> _editDate(TransactionDraft d) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: d.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => d.date = picked);
    }
  }

  Future<void> _editKeterangan(TransactionDraft d) async {
    final newValue = await showTransactionTextEditor(
      context,
      title: 'KETERANGAN',
      initialValue: d.sourceOrPayee,
      hint: 'Toko atau item utama (mis. Indomaret, Warmindo)',
    );
    if (newValue != null) {
      setState(() => d.sourceOrPayee = newValue.trim());
    }
  }

  Future<void> _editCatatan(TransactionDraft d) async {
    final newValue = await showTransactionTextEditor(
      context,
      title: 'CATATAN',
      initialValue: d.notes,
      hint: 'mis. promo cashback, daftar item utama',
      multiline: true,
    );
    if (newValue != null) {
      setState(() => d.notes = newValue.trim());
    }
  }

  // ────────────── LOADING / ERROR UI ──────────────

  Widget _buildLoading(String label) {
    final secondary = ThemeUtils.getTextSecondary(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_imageBytes != null) ...[
            Container(
              width: 140,
              decoration: BoxDecoration(
                border: Border.all(
                  color: ThemeUtils.isDarkMode(context)
                      ? AppTheme.darkHairlineColor
                      : AppTheme.hairlineColor,
                  width: AppTheme.hairlineWidth,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: AppTheme.space20),
          ],
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              const AccentBar(
                width: 24,
                height: 2,
                color: AppTheme.expenseColor,
              ),
              const SizedBox(width: AppTheme.space8),
              Eyebrow('GAGAL', color: AppTheme.expenseColor),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            _errorMessage,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ink,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            'Coba ulangi: pastikan struk terlihat utuh, tidak buram, dan '
            'angka totalnya jelas.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          FilledButton(
            onPressed: _reset,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: ThemeUtils.getBackgroundColor(context),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space24,
                vertical: AppTheme.space16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            child: Text(
              'COBA LAGI',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
