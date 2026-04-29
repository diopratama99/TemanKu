import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _auth;
  AuthNotifier(this._auth);

  bool get isLoggedIn => _auth.currentUserId != null;
  Map<String, dynamic>? get user => _auth.currentUser;
  String? get userId => _auth.currentUserId;

  Future<String?> login(String email, String password) async {
    final res = await _auth.login(email: email, password: password);
    notifyListeners();
    return res;
  }

  Future<String?> register(String name, String email, String password) async {
    final res = await _auth.register(
      name: name,
      email: email,
      password: password,
    );
    notifyListeners();
    return res;
  }

  Future<String?> verifyOtp(String email, String token) async {
    final res = await _auth.verifyOtp(email: email, token: token);
    notifyListeners();
    return res;
  }

  Future<void> logout() async {
    await _auth.logout();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await _auth.refreshCurrentUser();
    notifyListeners();
  }

  Future<String?> updatePassword(String newPassword) async {
    return await _auth.updatePassword(newPassword);
  }
}
