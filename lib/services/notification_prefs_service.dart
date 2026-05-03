import 'package:shared_preferences/shared_preferences.dart';

/// Manages user preferences for the notification listener feature.
/// Two independent switches:
///   - Auto account transfers (top-up, tarik tunai, transfer antar akun)
///   - Auto add transactions (pembayaran/pembelian)
class NotificationPrefsService {
  static const _keyAutoTransfer = 'notif_auto_transfer_enabled';
  static const _keyAutoTransaction = 'notif_auto_transaction_enabled';

  static NotificationPrefsService? _instance;
  SharedPreferences? _prefs;

  NotificationPrefsService._();
  factory NotificationPrefsService() => _instance ??= NotificationPrefsService._();

  Future<void> _ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── Auto Transfer ────────────────────────────────────────────────────

  Future<bool> get autoTransferEnabled async {
    await _ensureInit();
    return _prefs!.getBool(_keyAutoTransfer) ?? false;
  }

  Future<void> setAutoTransfer(bool value) async {
    await _ensureInit();
    await _prefs!.setBool(_keyAutoTransfer, value);
  }

  // ─── Auto Transaction ─────────────────────────────────────────────────

  Future<bool> get autoTransactionEnabled async {
    await _ensureInit();
    return _prefs!.getBool(_keyAutoTransaction) ?? false;
  }

  Future<void> setAutoTransaction(bool value) async {
    await _ensureInit();
    await _prefs!.setBool(_keyAutoTransaction, value);
  }

  // ─── Convenience ──────────────────────────────────────────────────────

  /// True if at least one switch is enabled (used to decide whether to
  /// prompt user for notification access permission).
  Future<bool> get anyEnabled async {
    final a = await autoTransferEnabled;
    final b = await autoTransactionEnabled;
    return a || b;
  }
}
