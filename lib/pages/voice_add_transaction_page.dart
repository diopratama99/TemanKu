import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/app_database.dart';
import '../services/voice_transaction_service.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

/// Phases the voice flow can be in.
enum _Phase { idle, listening, transcribing, parsing, preview, error }

/// Mutable draft used in the preview phase so the user can tweak any field
/// before committing.
class _VoiceDraft {
  String type;
  int amount;
  int categoryId;
  String categoryName;
  String? categoryEmoji;
  String account;
  String sourceOrPayee;
  String notes;
  DateTime date;
  final String confidence;
  final String reasoning;
  final String transcript;

  _VoiceDraft({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.account,
    required this.sourceOrPayee,
    required this.notes,
    required this.date,
    required this.confidence,
    required this.reasoning,
    required this.transcript,
  });

  factory _VoiceDraft.fromParsed(ParsedTransaction p) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(p.date);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return _VoiceDraft(
      type: p.type,
      amount: p.amount,
      categoryId: p.categoryId,
      categoryName: p.categoryName,
      categoryEmoji: p.categoryEmoji,
      account: p.account,
      sourceOrPayee: p.sourceOrPayee,
      notes: p.notes,
      date: parsedDate,
      confidence: p.confidence,
      reasoning: p.reasoning,
      transcript: p.transcript,
    );
  }

  Map<String, dynamic> toInsertPayload() {
    return {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'source_or_payee': sourceOrPayee,
      'account': account,
      'notes': notes,
    };
  }
}

class VoiceAddTransactionPage extends StatefulWidget {
  const VoiceAddTransactionPage({super.key});

  @override
  State<VoiceAddTransactionPage> createState() =>
      _VoiceAddTransactionPageState();
}

class _VoiceAddTransactionPageState extends State<VoiceAddTransactionPage>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final VoiceTransactionService _voiceService = VoiceTransactionService();

  late final AnimationController _pulse;

  _Phase _phase = _Phase.idle;
  String _transcript = '';
  String _errorMessage = '';
  final List<_VoiceDraft> _drafts = [];
  bool _saving = false;
  String? _selectedLocaleId;
  bool _initialized = false;

  static const _examples = [
    'Beli batagor 20rb pakai cash',
    'Beli batagor 20rb lalu bayar parkir 5rb',
    'Bayar bensin 50 ribu transfer',
    'Top up gopay 100 ribu',
    'Dapat gaji 5 juta masuk rekening',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStt());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _setError(
        'Izin mikrofon ditolak. Aktifkan di pengaturan untuk pakai fitur ini.',
      );
      return;
    }

    final ok = await _stt.initialize(
      onError: (e) {
        if (!mounted) return;
        _setError('Speech error: ${e.errorMsg}');
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          if (_phase == _Phase.listening && _transcript.trim().isEmpty) {
            setState(() => _phase = _Phase.idle);
          }
        }
      },
    );
    if (!ok) {
      _setError('Speech recognition tidak tersedia di perangkat ini.');
      return;
    }

    // Pick best matching Indonesian locale.
    final locales = await _stt.locales();
    final id = locales.firstWhere(
      (l) => l.localeId.toLowerCase().startsWith('id'),
      orElse: () => locales.isNotEmpty
          ? locales.first
          : stt.LocaleName('en_US', 'English'),
    );
    if (!mounted) return;
    setState(() {
      _selectedLocaleId = id.localeId;
      _initialized = true;
    });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorMessage = msg;
    });
  }

  Future<void> _startListening() async {
    if (!_initialized) {
      await _initStt();
      if (!_initialized) return;
    }
    setState(() {
      _phase = _Phase.listening;
      _transcript = '';
      _errorMessage = '';
      _drafts.clear();
    });
    await _stt.listen(
      localeId: _selectedLocaleId,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      onResult: (res) {
        if (!mounted) return;
        setState(() => _transcript = res.recognizedWords);
      },
    );
  }

  Future<void> _stopAndParse() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    setState(() => _phase = _Phase.parsing);
    try {
      final parsed = await _voiceService.parse(text);
      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(parsed.map(_VoiceDraft.fromParsed));
        _phase = _Phase.preview;
      });
    } on VoiceParseException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Tidak terhubung: $e');
    }
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
        // Nothing left to save -> bounce back to idle so user can re-record.
        _phase = _Phase.idle;
        _transcript = '';
      }
    });
  }

  void _reset() {
    setState(() {
      _phase = _Phase.idle;
      _transcript = '';
      _errorMessage = '';
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
            EditorialHeader(
              eyebrow: 'SUARA',
              title: 'Catat\nlewat suara.',
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
      case _Phase.preview:
        return _buildPreview();
      case _Phase.parsing:
        return _buildLoading('Sedang memahami ucapanmu...');
      case _Phase.transcribing:
        return _buildLoading('Memproses suara...');
      case _Phase.error:
        return _buildError();
      case _Phase.listening:
      case _Phase.idle:
        return _buildIdleOrListening();
    }
  }

  // ────────────── IDLE / LISTENING UI ──────────────

  Widget _buildIdleOrListening() {
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isListening = _phase == _Phase.listening;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.space16),

          // Transcript canvas
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_transcript.isNotEmpty) ...[
                    Eyebrow('TRANSKRIP', color: secondary),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      _transcript,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        AccentBar(width: 24, height: 2, color: accent),
                        const SizedBox(width: AppTheme.space8),
                        Eyebrow('CONTOH', color: secondary),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),
                    for (final ex in _examples) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.space12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ex,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: ink,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.space16),
                    Text(
                      'Tekan tombol mikrofon di bawah, ucapkan transaksimu, '
                      'lalu tekan ulang untuk berhenti. TemanKu akan '
                      'menyusun draftnya untukmu.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Mic button
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.space16,
              bottom: AppTheme.space24,
            ),
            child: Column(
              children: [
                _MicButton(
                  isListening: isListening,
                  pulse: _pulse,
                  onTap: () {
                    if (isListening) {
                      _stopAndParse();
                    } else {
                      _startListening();
                    }
                  },
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  isListening
                      ? 'Mendengarkan... tekan untuk berhenti'
                      : 'Tekan untuk mulai bicara',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: secondary,
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
    final sharedTranscript = _drafts.first.transcript;

    final saveLabel = total == 1 ? 'SIMPAN' : 'SIMPAN $total';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageGutter,
        0,
        AppTheme.pageGutter,
        AppTheme.space40,
      ),
      children: [
        // Top bar: DRAFT label + count + edit hint
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

        // Original transcript (shared across siblings)
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
              Eyebrow('UCAPANMU', color: secondary),
              const SizedBox(height: AppTheme.space8),
              Text(
                '"$sharedTranscript"',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
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

  Widget _buildDraftSection(int index, _VoiceDraft d, int total) {
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
              _ConfidenceBadge(level: d.confidence),
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
              _ConfidenceBadge(level: d.confidence),
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
        _PreviewRow(
          label: 'KATEGORI',
          value:
              '${d.categoryEmoji != null ? '${d.categoryEmoji} ' : ''}${d.categoryName}',
          onTap: () => _editCategory(d),
        ),
        _PreviewRow(
          label: 'AKUN',
          value: d.account,
          onTap: () => _editAccount(d),
        ),
        _PreviewRow(
          label: 'TANGGAL',
          value: DateFormat('d MMMM yyyy', 'id_ID').format(d.date),
          onTap: () => _editDate(d),
        ),
        _PreviewRow(
          label: 'KETERANGAN',
          value: d.sourceOrPayee.isEmpty ? '(kosong)' : d.sourceOrPayee,
          muted: d.sourceOrPayee.isEmpty,
          onTap: () => _editKeterangan(d),
        ),
        _PreviewRow(
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
      // Only one left -> removing it is the same as resetting.
      _reset();
      return;
    }
    _removeDraft(index);
  }

  // ────────────── EDIT HANDLERS ──────────────

  void _editType(_VoiceDraft d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeUtils.getBackgroundColor(context),
      builder: (ctx) => _SimpleChoiceSheet(
        title: 'JENIS TRANSAKSI',
        current: d.type,
        choices: const [('expense', 'Pengeluaran'), ('income', 'Pemasukan')],
        onSelected: (v) async {
          if (v == d.type) return;
          // Switching type: pick the first available category of the new type.
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

  Future<void> _editAmount(_VoiceDraft d) async {
    final newValue = await _showTextEditor(
      title: 'JUMLAH (Rp)',
      initialValue: d.amount == 0 ? '' : d.amount.toString(),
      keyboardType: TextInputType.number,
      hint: 'mis. 20000',
    );
    if (newValue == null) return;
    final clean = newValue.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean);
    if (parsed == null) return;
    setState(() => d.amount = parsed);
  }

  Future<void> _editCategory(_VoiceDraft d) async {
    try {
      final cats = await context.read<AppDatabase>().getCategories(d.type);
      if (!mounted || cats.isEmpty) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: ThemeUtils.getBackgroundColor(context),
        isScrollControlled: true,
        builder: (ctx) => _CategoryPickerSheet(
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

  void _editAccount(_VoiceDraft d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeUtils.getBackgroundColor(context),
      builder: (ctx) => _SimpleChoiceSheet(
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

  Future<void> _editDate(_VoiceDraft d) async {
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

  Future<void> _editKeterangan(_VoiceDraft d) async {
    final newValue = await _showTextEditor(
      title: 'KETERANGAN',
      initialValue: d.sourceOrPayee,
      hint: 'Item, tempat, atau pihak (mis. batagor di Warung Bu Ani)',
    );
    if (newValue != null) {
      setState(() => d.sourceOrPayee = newValue.trim());
    }
  }

  Future<void> _editCatatan(_VoiceDraft d) async {
    final newValue = await _showTextEditor(
      title: 'CATATAN',
      initialValue: d.notes,
      hint: 'mis. utang dulu ke Budi, split bill bertiga',
      multiline: true,
    );
    if (newValue != null) {
      setState(() => d.notes = newValue.trim());
    }
  }

  Future<String?> _showTextEditor({
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

  Widget _buildLoading(String label) {
    final secondary = ThemeUtils.getTextSecondary(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            'Coba ulangi dengan kalimat yang lebih jelas, '
            'sebut jumlah dan kategori secara langsung.',
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

// =====================================================================
// Sub-widgets
// =====================================================================

class _MicButton extends StatelessWidget {
  final bool isListening;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final paper = ThemeUtils.getBackgroundColor(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 130,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isListening)
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) {
                  return Container(
                    width: 100 + 30 * pulse.value,
                    height: 100 + 30 * pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(
                          alpha: 0.5 - 0.4 * pulse.value,
                        ),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: isListening ? accent : ink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: paper,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool muted;
  const _PreviewRow({
    required this.label,
    required this.value,
    this.onTap,
    this.muted = false,
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

// =====================================================================
// Edit sheets
// =====================================================================

class _SimpleChoiceSheet extends StatelessWidget {
  final String title;
  final String current;
  final List<(String, String)> choices;
  final ValueChanged<String> onSelected;
  const _SimpleChoiceSheet({
    required this.title,
    required this.current,
    required this.choices,
    required this.onSelected,
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

class _CategoryPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int currentId;
  final ValueChanged<Map<String, dynamic>> onSelected;
  const _CategoryPickerSheet({
    required this.categories,
    required this.currentId,
    required this.onSelected,
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

class _ConfidenceBadge extends StatelessWidget {
  final String level;
  const _ConfidenceBadge({required this.level});

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
