import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _db = AppDatabase();

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  Future<void> loadSession() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      await _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final profile = await _db.getProfile();
    if (profile != null) {
      _currentUser = profile;
    } else {
      // Fallback: build minimal user map from auth so UI doesn't crash
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        _currentUser = {
          'id': authUser.id,
          'name':
              authUser.userMetadata?['name'] ??
              authUser.email?.split('@').first ??
              'Pengguna',
          'email': authUser.email,
          'picture': null,
        };
      }
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'name': name},
      );

      if (res.user == null) {
        return 'Gagal daftar. Coba lagi.';
      }

      // User needs to verify OTP before session is active
      // Profile + default categories are created by DB trigger after verification
      return null;
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) {
        return 'Email sudah terdaftar';
      }
      return 'Gagal daftar: ${e.message}';
    } catch (e) {
      return 'Gagal daftar: $e';
    }
  }

  Future<String?> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      );

      if (res.session == null) {
        return 'Kode verifikasi salah atau sudah kedaluwarsa';
      }

      // Now session is active, load/update profile
      await _loadProfile();
      return null;
    } on AuthException catch (e) {
      return 'Verifikasi gagal: ${e.message}';
    } catch (e) {
      return 'Verifikasi gagal: $e';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (res.session == null) {
        return 'Email atau password salah';
      }

      await _loadProfile();
      return null;
    } on AuthException catch (_) {
      return 'Email atau password salah';
    } catch (e) {
      return 'Gagal login: $e';
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
  }

  Future<void> refreshCurrentUser() async {
    await _loadProfile();
  }

  Future<String?> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
      return null;
    } on AuthException catch (e) {
      return 'Gagal mengirim kode: ${e.message}';
    } catch (e) {
      return 'Gagal mengirim kode: $e';
    }
  }

  Future<String?> verifyOtpRecovery({
    required String email,
    required String token,
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.recovery,
      );
      if (res.session == null) {
        return 'Kode salah atau sudah kedaluwarsa';
      }
      await _loadProfile();
      return null;
    } on AuthException catch (e) {
      return 'Verifikasi gagal: ${e.message}';
    } catch (e) {
      return 'Verifikasi gagal: $e';
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal mengubah password: $e';
    }
  }
}
