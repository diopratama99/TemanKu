import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  late DateTime _start;
  late DateTime _end;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
  }

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    final db = context.read<AppDatabase>();
    final rows = await db.getTransactions(
      startDate: _iso(_start),
      endDate: _iso(_end),
    );
    // Sort ascending for export
    rows.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    final csvRows = <List<dynamic>>[
      [
        'date',
        'type',
        'category',
        'amount',
        'source_or_payee',
        'account',
        'notes',
      ],
      ...rows.map(
        (r) => [
          r['date'],
          r['type'],
          r['category'],
          r['amount'],
          r['source_or_payee'] ?? '',
          r['account'] ?? '',
          r['notes'] ?? '',
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(csvRows);
    final tempDir = await getTemporaryDirectory();
    final file = File(
      p.join(tempDir.path, 'temanku_${_iso(_start)}_${_iso(_end)}.csv'),
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Export TemanKu');
    setState(() => _busy = false);
  }

  Future<void> _importCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (res == null || res.files.single.path == null) return;
    setState(() => _busy = true);
    final file = File(res.files.single.path!);
    final content = await file.readAsString();
    final parsed = const CsvToListConverter().convert(content, eol: '\n');
    // Expect header in first row
    final header = parsed.first.map((e) => e.toString()).toList();
    final idx = {
      for (var i = 0; i < header.length; i++) header[i].toLowerCase(): i,
    };
    final db = context.read<AppDatabase>();
    for (int i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      String date = row[idx['date']!].toString();
      String type = row[idx['type']!].toString();
      String categoryName = row[idx['category']!].toString();
      final amount = double.tryParse(row[idx['amount']!].toString()) ?? 0.0;
      final payee = idx.containsKey('source_or_payee')
          ? row[idx['source_or_payee']!].toString()
          : '';
      final account = idx.containsKey('account')
          ? row[idx['account']!].toString()
          : '';
      final notes = idx.containsKey('notes')
          ? row[idx['notes']!].toString()
          : '';

      // Ensure category exists
      final cats = await db.getCategories(type);
      int catId;
      final match = cats.where((c) => c['name'] == categoryName).toList();
      if (match.isEmpty) {
        final newCat = await db.insertCategory({
          'type': type,
          'name': categoryName,
        });
        catId = newCat['id'] as int;
      } else {
        catId = match.first['id'] as int;
      }

      await db.insertTransaction({
        'date': date,
        'type': type,
        'category_id': catId,
        'amount': amount,
        'source_or_payee': payee,
        'account': account,
        'notes': notes,
      });
    }
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Import selesai')));
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accent = ThemeUtils.getPrimaryColor(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorialHeader(
              eyebrow: 'ARSIP',
              title: 'Salin & cadangkan.',
              metaEyebrow: 'PERIODE',
              meta: '${_iso(_start)}\n${_iso(_end)}',
              titleSize: 32,
              showBackButton: true,
            ),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // Period picker
                  const SizedBox(height: AppTheme.space8),
                  _IORowAction(
                    eyebrow: 'MULAI',
                    title: _iso(_start),
                    caption: 'Tanggal awal export',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _start = picked);
                    },
                  ),
                  _IORowAction(
                    eyebrow: 'AKHIR',
                    title: _iso(_end),
                    caption: 'Tanggal akhir export',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _end,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _end = picked);
                    },
                  ),

                  // Export section
                  const SizedBox(height: AppTheme.space24),
                  const EditorialSectionHeader(
                    eyebrow: 'EKSPOR',
                    title: 'Bagikan catatanmu',
                  ),
                  _IORowAction(
                    eyebrow: 'CSV',
                    title: 'Bagikan file CSV',
                    caption: 'Buka share sheet sistem',
                    icon: Icons.ios_share_outlined,
                    onTap: _busy ? null : _exportCsv,
                  ),
                  // Import section
                  const SizedBox(height: AppTheme.space24),
                  const EditorialSectionHeader(
                    eyebrow: 'IMPOR',
                    title: 'Muat ulang dari berkas',
                  ),
                  _IORowAction(
                    eyebrow: 'CSV',
                    title: 'Pilih berkas .csv',
                    caption: 'Format kolom: date, type, category, amount, ...',
                    icon: Icons.file_upload_outlined,
                    onTap: _busy ? null : _importCsv,
                  ),

                  if (_busy) ...[
                    const Hairline(),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.space24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Text(
                            'Memproses...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w600,
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.space40),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.pageGutter,
                    ),
                    child: Text(
                      'CSV TemanKu menggunakan koma sebagai pemisah. Kolom wajib: date, type, category, amount.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.6,
                        color: secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),
                  _ColophonNote(ink: ink, secondary: secondary),
                  const SizedBox(height: AppTheme.space40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editorial-styled actionable row.
class _IORowAction extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool accent;

  const _IORowAction({
    required this.eyebrow,
    required this.title,
    this.caption,
    this.icon,
    this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final accentColor = ThemeUtils.getPrimaryColor(context);
    final disabled = onTap == null;

    return Column(
      children: [
        const Hairline(),
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
                        Eyebrow(eyebrow, color: secondary),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: disabled ? secondary : ink,
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
                  if (icon != null) ...[
                    const SizedBox(width: AppTheme.space16),
                    Icon(icon, size: 22, color: accent ? accentColor : ink),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColophonNote extends StatelessWidget {
  final Color ink;
  final Color secondary;
  const _ColophonNote({required this.ink, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          const SizedBox(height: AppTheme.space16),
          Eyebrow('KOLOFON', color: secondary),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Ekspor dalam format CSV yang kompatibel dengan Excel, Google Sheets, dan aplikasi keuangan lainnya.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.6,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}
