import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import '../widgets/editorial.dart';
import '../widgets/state_widgets.dart';

/// Editorial cover-style login. Magazine masthead at the top,
/// huge display title, segmented underline tabs, hairline form fields.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regUsername = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  bool _busy = false;
  bool _obscureLoginPassword = true;
  bool _obscureRegPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regUsername.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    setState(() => _busy = true);
    String? err;
    try {
      final auth = context.read<AuthNotifier>();
      err = await auth.login(_loginEmail.text, _loginPassword.text);
    } catch (e) {
      err = 'Gagal masuk: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (err != null) {
      showErrorSnackbar(context, err);
    } else {
      showSuccessSnackbar(context, 'Selamat datang kembali');
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _doRegister() async {
    if (_regUsername.text.trim().isEmpty) {
      showErrorSnackbar(context, 'Nama pengguna tidak boleh kosong');
      return;
    }
    if (_regEmail.text.trim().isEmpty) {
      showErrorSnackbar(context, 'Email tidak boleh kosong');
      return;
    }
    setState(() => _busy = true);
    String? err;
    try {
      final auth = context.read<AuthNotifier>();
      err = await auth.register(
        _regUsername.text.trim(),
        _regEmail.text.trim(),
        _regPassword.text,
      );
    } catch (e) {
      err = 'Gagal daftar: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (err != null) {
      showErrorSnackbar(context, err);
    } else {
      // Navigate to OTP verification page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _OtpVerificationPage(email: _regEmail.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppDatabase>();
    if (context.watch<AuthNotifier>().isLoggedIn) {
      // Will be redirected by MaterialApp home builder
    }

    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final accent = ThemeUtils.getPrimaryColor(context);
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final edition = DateFormat('MMMM yyyy', 'id')
        .format(DateTime.now())
        .toUpperCase();

    return Scaffold(
      backgroundColor: paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space24,
            AppTheme.pageGutter,
            AppTheme.space32 +
                MediaQuery.of(context).viewInsets.bottom * 0.1,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  MediaQuery.of(context).viewInsets.bottom -
                  AppTheme.space64,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Masthead — magazine name + edition + line below
                if (!isKeyboardVisible) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Eyebrow('TEMANKU · EDISI $edition'),
                      ),
                      Eyebrow('No. 01', color: secondary),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  const Hairline(thickness: 2),
                  const SizedBox(height: AppTheme.space40),
                ] else ...[
                  const SizedBox(height: AppTheme.space12),
                ],

                // Cover — display title + tagline asymmetric
                if (!isKeyboardVisible) ...[
                  DisplayTitle(
                    'Cerita\nKeuangan\nKamu.',
                    size: 44,
                    weight: FontWeight.w600,
                  ),
                  const SizedBox(height: AppTheme.space20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Halaman terbuka untuk catatan, anggaran, dan target. '
                          'Ditulis dengan tenang, dibaca dengan jelas.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.6,
                            color: secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Eyebrow('OLEH', color: secondary),
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              'Teman\nLabs',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space32),
                ],

                // Tabs — underline only, indigo accent
                _buildSegmented(ink, secondary, accent),
                const SizedBox(height: AppTheme.space24),

                // Form
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: IndexedStack(
                    index: _tabController.index,
                    sizing: StackFit.loose,
                    children: [_buildLogin(), _buildRegister()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmented(Color ink, Color secondary, Color accent) {
    final tabs = ['MASUK', 'DAFTAR'];
    return Column(
      children: [
        Row(
          children: List.generate(tabs.length, (i) {
            final selected = _tabController.index == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_tabController.index != i) {
                    _tabController.animateTo(i);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? ThemeUtils.getAccentGreen(context)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabs[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: selected ? ink : secondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _buildLogin() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTheme.space12),
        _Field(
          label: 'ALAMAT EMAIL',
          controller: _loginEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppTheme.space20),
        _Field(
          label: 'KATA SANDI',
          controller: _loginPassword,
          obscure: _obscureLoginPassword,
          onToggleObscure: () => setState(() {
            _obscureLoginPassword = !_obscureLoginPassword;
          }),
        ),
        const SizedBox(height: AppTheme.space32),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _busy ? null : _doLogin,
            style: FilledButton.styleFrom(
              backgroundColor: ThemeUtils.getPrimaryColor(context),
            ),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('MASUK SEKARANG'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegister() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTheme.space12),
        _Field(
          label: 'NAMA PENGGUNA',
          controller: _regUsername,
        ),
        const SizedBox(height: AppTheme.space20),
        _Field(
          label: 'ALAMAT EMAIL',
          controller: _regEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppTheme.space20),
        _Field(
          label: 'KATA SANDI',
          controller: _regPassword,
          obscure: _obscureRegPassword,
          onToggleObscure: () => setState(() {
            _obscureRegPassword = !_obscureRegPassword;
          }),
        ),
        const SizedBox(height: AppTheme.space32),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _busy ? null : _doRegister,
            style: FilledButton.styleFrom(
              backgroundColor: ThemeUtils.getPrimaryColor(context),
            ),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('TERBITKAN AKUN'),
          ),
        ),
      ],
    );
  }
}

/// Editorial underline-style field with a small uppercase label above.
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ThemeUtils.getTextPrimary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: ink,
            letterSpacing: -0.1,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: const UnderlineInputBorder(),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    splashRadius: 20,
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// OTP email verification page shown after registration.
class _OtpVerificationPage extends StatefulWidget {
  final String email;
  const _OtpVerificationPage({required this.email});

  @override
  State<_OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<_OtpVerificationPage> {
  final _otpController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otpController.text.trim().isEmpty) {
      showErrorSnackbar(context, 'Masukkan kode verifikasi');
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthNotifier>().verifyOtp(
      widget.email,
      _otpController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showErrorSnackbar(context, err);
    } else {
      showSuccessSnackbar(context, 'Akun berhasil diverifikasi!');
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pageGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.space40),
              EditorialHeader(
                eyebrow: 'VERIFIKASI',
                title: 'Cek email\nkamu.',
                titleSize: 36,
                showHairline: false,
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                'Kami sudah mengirim kode verifikasi ke:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: secondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                widget.email,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: AppTheme.space32),
              Eyebrow('KODE VERIFIKASI'),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 8,
                  color: ink,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: UnderlineInputBorder(),
                  hintText: '000000',
                ),
                maxLength: 6,
              ),
              const SizedBox(height: AppTheme.space32),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _busy ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeUtils.getPrimaryColor(context),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('VERIFIKASI'),
                ),
              ),
              const SizedBox(height: AppTheme.space24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'KEMBALI KE LOGIN',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
