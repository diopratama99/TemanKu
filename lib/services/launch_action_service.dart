import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LaunchAction {
  openVoiceTransaction,
  openCameraTransaction,
  openHistoryTransaction,
  openHistoryTransfer,
}

class LaunchActionService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('temanku/navigation');

  LaunchAction? _pendingAction;
  LaunchAction? get pendingAction => _pendingAction;

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      final initial = await _channel.invokeMethod<String>('getInitialAction');
      _setPendingAction(initial);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'openVoiceTransaction') {
      _setPendingAction('open_voice_transaction');
    } else if (call.method == 'openCameraTransaction') {
      _setPendingAction('open_camera_transaction');
    } else if (call.method == 'openHistoryTransaction') {
      _setPendingAction('open_history_transaction');
    } else if (call.method == 'openHistoryTransfer') {
      _setPendingAction('open_history_transfer');
    }
  }

  LaunchAction? consumeAction() {
    final action = _pendingAction;
    if (action != null) {
      _pendingAction = null;
      notifyListeners();
    }
    return action;
  }

  void _setPendingAction(String? rawAction) {
    final next = switch (rawAction) {
      'open_voice_transaction' => LaunchAction.openVoiceTransaction,
      'open_camera_transaction' => LaunchAction.openCameraTransaction,
      'open_history_transaction' => LaunchAction.openHistoryTransaction,
      'open_history_transfer' => LaunchAction.openHistoryTransfer,
      _ => null,
    };
    if (next == _pendingAction) return;
    _pendingAction = next;
    notifyListeners();
  }
}
