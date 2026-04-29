import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _LoginPageState extends State<LoginPage> {
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  bool _busy = false;
  bool _obscureLoginPassword = true;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
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

  @override
  Widget build(BuildContext context) {
    context.watch<AppDatabase>();
    if (context.watch<AuthNotifier>().isLoggedIn) {
      // Will be redirected by MaterialApp home builder
    }

    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            AppTheme.space24,
            AppTheme.pageGutter,
            AppTheme.space32 + MediaQuery.of(context).viewInsets.bottom * 0.1,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
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
                    children: const [Expanded(child: Eyebrow('TEMANKU'))],
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
                    ],
                  ),
                  const SizedBox(height: AppTheme.space32),
                ],

                // Form
                _buildLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    final secondary = ThemeUtils.getTextSecondary(context);
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
        const SizedBox(height: AppTheme.space12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ForgotPasswordPage()),
              );
            },
            child: Text(
              'Lupa kata sandi?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ThemeUtils.getPrimaryColor(context),
              ),
            ),
          ),
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
        const SizedBox(height: AppTheme.space24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Belum punya akun? ',
              style: GoogleFonts.inter(fontSize: 14, color: secondary),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _RegisterPage()),
                );
              },
              child: Text(
                'Daftar',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ThemeUtils.getPrimaryColor(context),
                ),
              ),
            ),
          ],
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

/// Register page — separate from login.
class _RegisterPage extends StatefulWidget {
  const _RegisterPage();

  @override
  State<_RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<_RegisterPage> {
  final _regUsername = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _regUsername.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _OtpVerificationPage(email: _regEmail.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    return Scaffold(
      backgroundColor: paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pageGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.space40),
              EditorialHeader(
                eyebrow: 'DAFTAR',
                title: 'Buat akun\nbaru.',
                titleSize: 36,
                showHairline: false,
                showMasthead: false,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppTheme.space32),
              _Field(label: 'NAMA PENGGUNA', controller: _regUsername),
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
                obscure: _obscurePassword,
                onToggleObscure: () => setState(() {
                  _obscurePassword = !_obscurePassword;
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
                      : const Text('DAFTAR SEKARANG'),
                ),
              ),
              const SizedBox(height: AppTheme.space24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sudah punya akun? ',
                    style: GoogleFonts.inter(fontSize: 14, color: secondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Masuk',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ThemeUtils.getPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Forgot password page — sends OTP code then verifies, then allows new password.
class _ForgotPasswordPage extends StatefulWidget {
  const _ForgotPasswordPage();

  @override
  State<_ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<_ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  // 0 = enter email, 1 = enter OTP code, 2 = set new password
  int _step = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailController.text.trim().isEmpty) {
      showErrorSnackbar(context, 'Masukkan alamat email');
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthNotifier>().resetPasswordForEmail(
      _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showErrorSnackbar(context, err);
    } else {
      showSuccessSnackbar(context, 'Kode verifikasi telah dikirim ke email');
      setState(() => _step = 1);
    }
  }

  Future<void> _verifyCode() async {
    if (_otpController.text.trim().isEmpty) {
      showErrorSnackbar(context, 'Masukkan kode verifikasi');
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthNotifier>().verifyOtpRecovery(
      _emailController.text.trim(),
      _otpController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showErrorSnackbar(context, err);
    } else {
      setState(() => _step = 2);
    }
  }

  Future<void> _setNewPassword() async {
    if (_newPasswordController.text.isEmpty) {
      showErrorSnackbar(context, 'Masukkan kata sandi baru');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      showErrorSnackbar(context, 'Kata sandi minimal 6 karakter');
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthNotifier>().updatePassword(
      _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showErrorSnackbar(context, err);
    } else {
      showSuccessSnackbar(context, 'Kata sandi berhasil diubah!');
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pageGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.space40),
              EditorialHeader(
                eyebrow: _step == 0
                    ? 'LUPA SANDI'
                    : _step == 1
                    ? 'VERIFIKASI'
                    : 'SANDI BARU',
                title: _step == 0
                    ? 'Reset\nkata sandi.'
                    : _step == 1
                    ? 'Masukkan\nkode.'
                    : 'Buat sandi\nbaru.',
                titleSize: 36,
                showHairline: false,
                showMasthead: false,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppTheme.space16),

              if (_step == 0) ...[
                Text(
                  'Masukkan email yang terdaftar. Kami akan mengirim kode verifikasi untuk mereset kata sandi.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: secondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space32),
                _Field(
                  label: 'ALAMAT EMAIL',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppTheme.space32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _sendCode,
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
                        : const Text('KIRIM KODE'),
                  ),
                ),
              ],

              if (_step == 1) ...[
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
                  _emailController.text.trim(),
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
                    onPressed: _busy ? null : _verifyCode,
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
              ],

              if (_step == 2) ...[
                Text(
                  'Masukkan kata sandi baru untuk akunmu.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: secondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space32),
                _Field(
                  label: 'KATA SANDI BARU',
                  controller: _newPasswordController,
                  obscure: _obscurePassword,
                  onToggleObscure: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                ),
                const SizedBox(height: AppTheme.space32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _setNewPassword,
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
                        : const Text('SIMPAN SANDI BARU'),
                  ),
                ),
              ],

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
