import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import 'notification_prefs_service.dart';

/// Receives financial notifications from native Android via MethodChannel
/// and processes them:
///   - Sends text to Supabase `parse-notification` edge function (AI)
///   - Based on response, auto-inserts transaction or account transfer
///   - Sends a local push notification to alert the user
///   - Stores pending reviews so the user sees a popup on next app open
///
/// Android-only. On iOS this service does nothing.
class NotificationListenerService extends ChangeNotifier {
  static const _channel = MethodChannel('temanku/notifications');
  static const _pendingKey = 'notif_pending_reviews';

  final _prefs = NotificationPrefsService();
  final _db = AppDatabase();

  bool _initialized = false;

  /// Last processed notification info (for UI feedback).
  String? lastNotification;
  String? lastAction; // "transaction", "transfer", "ignore"
  String? lastError;

  /// Pending reviews accumulated while app may be in background.
  List<Map<String, dynamic>> _pendingReviews = [];
  List<Map<String, dynamic>> get pendingReviews => _pendingReviews;

  /// Initialize the MethodChannel handler. Safe to call multiple times.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      await _processNotification(data);
    }
  }

  /// Public entry point for debug/testing — simulates a notification
  /// without going through the native MethodChannel.
  Future<void> simulateNotification({
    required String notificationText,
    required String packageName,
  }) async {
    await _processNotification({
      'notification_text': notificationText,
      'package_name': packageName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Load pending reviews from SharedPreferences (called on app start).
  Future<void> loadPendingReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingKey) ?? [];
    _pendingReviews = raw
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Clear all pending reviews (called after user has seen the popup).
  Future<void> clearPendingReviews() async {
    _pendingReviews.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    notifyListeners();
  }

  /// Persist a review item to SharedPreferences.
  Future<void> _addPendingReview(Map<String, dynamic> review) async {
    _pendingReviews.add(review);
    final prefs = await SharedPreferences.getInstance();
    final raw = _pendingReviews.map((r) => jsonEncode(r)).toList();
    await prefs.setStringList(_pendingKey, raw);
    notifyListeners();
  }

  /// Send a local notification via native Android.
  Future<void> _sendLocalNotification(String title, String body, {String? action}) async {
    try {
      await _channel.invokeMethod('showLocalNotification', {
        'title': title,
        'body': body,
        if (action != null) 'action': action,
      });
    } catch (e) {
      debugPrint('[NotificationListener] Local notif error: $e');
    }
  }

  Future<void> _processNotification(Map<String, dynamic> data) async {
    final notifText = data['notification_text'] as String? ?? '';
    final packageName = data['package_name'] as String? ?? '';

    if (notifText.isEmpty) return;

    // Check if any feature is enabled
    final autoTransfer = await _prefs.autoTransferEnabled;
    final autoTransaction = await _prefs.autoTransactionEnabled;

    if (!autoTransfer && !autoTransaction) return;

    // Check auth
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    try {
      // Call Supabase edge function
      final response = await client.functions.invoke(
        'parse-notification',
        body: {
          'notification_text': notifText,
          'package_name': packageName,
        },
      );

      if (response.status != 200) {
        lastError = 'Edge function returned ${response.status}';
        notifyListeners();
        return;
      }

      // response.data can be a Map (already decoded) or a String (raw JSON)
      final Map<String, dynamic> result;
      if (response.data is Map) {
        result = Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is String) {
        result = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        lastError = 'Unexpected response type: ${response.data.runtimeType}';
        notifyListeners();
        return;
      }
      final action = result['action'] as String?;

      lastNotification = notifText;
      lastAction = action;
      lastError = null;

      if (action == 'transaction' && autoTransaction) {
        final txn = result['transaction'] as Map<String, dynamic>;
        final inserted = await _insertTransaction(txn);
        if (inserted != null) {
          // Store for popup review
          await _addPendingReview({
            'action': 'transaction',
            'id': inserted['id'],
            ...txn,
          });
          // Send local notification
          final amount = txn['amount'] ?? 0;
          final type = txn['type'] == 'income' ? 'Pemasukan' : 'Pengeluaran';
          await _sendLocalNotification(
            'Halo, ada kegiatan transaksi nih! 💰',
            '$type Rp$amount tercatat otomatis. Coba di cek ya!',
            action: 'transaction',
          );
        }
      } else if (action == 'transfer' && autoTransfer) {
        final transfer = result['transfer'] as Map<String, dynamic>;
        final success = await _insertTransfer(transfer);
        if (success) {
          await _addPendingReview({
            'action': 'transfer',
            ...transfer,
          });
          final amount = transfer['amount'] ?? 0;
          final from = transfer['from_account'] ?? '';
          final to = transfer['to_account'] ?? '';
          await _sendLocalNotification(
            'Halo, ada mutasi akun nih! 🔄',
            'Mutasi $from → $to Rp$amount tercatat otomatis. Coba di cek ya!',
            action: 'transfer',
          );
        }
      }

      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      debugPrint('[NotificationListener] Error: $e');
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _insertTransaction(Map<String, dynamic> txn) async {
    try {
      final result = await _db.insertTransaction({
        'type': txn['type'],
        'amount': txn['amount'],
        'category_id': txn['category_id'],
        'account': txn['account'] ?? 'Tunai',
        'source_or_payee': txn['source_or_payee'] ?? '',
        'notes': '${txn['notes'] ?? ''} [auto-notif]'.trim(),
        'date': txn['date'],
      });
      debugPrint('[NotificationListener] Auto-inserted transaction: ${txn['amount']}');
      return result;
    } catch (e) {
      debugPrint('[NotificationListener] Insert transaction error: $e');
      lastError = 'Gagal simpan transaksi: $e';
      return null;
    }
  }

  Future<bool> _insertTransfer(Map<String, dynamic> transfer) async {
    try {
      await _db.insertAccountTransferWithFee(
        dateIso: transfer['date'] as String,
        fromAccount: transfer['from_account'] as String,
        toAccount: transfer['to_account'] as String,
        amount: (transfer['amount'] as num).toDouble(),
        note: '${transfer['note'] ?? ''} [auto-notif]'.trim(),
      );
      debugPrint('[NotificationListener] Auto-inserted transfer: ${transfer['amount']}');
      return true;
    } catch (e) {
      debugPrint('[NotificationListener] Insert transfer error: $e');
      lastError = 'Gagal simpan mutasi: $e';
      return false;
    }
  }
}
