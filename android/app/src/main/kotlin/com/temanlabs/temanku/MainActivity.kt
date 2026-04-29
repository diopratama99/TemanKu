package com.temanlabs.temanku

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var navigationChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    navigationChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      CHANNEL,
    )
    navigationChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "getInitialAction" -> result.success(extractLaunchAction(intent))
        else -> result.notImplemented()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    val action = extractLaunchAction(intent) ?: return
    if (action == OPEN_VOICE_TRANSACTION) {
      navigationChannel?.invokeMethod("openVoiceTransaction", null)
    }
  }

  private fun extractLaunchAction(intent: Intent?): String? {
    if (intent == null) return null
    return if (
      intent.action == ACTION_OPEN_VOICE_TRANSACTION ||
      intent.getBooleanExtra(EXTRA_OPEN_VOICE_TRANSACTION, false)
    ) {
      OPEN_VOICE_TRANSACTION
    } else {
      null
    }
  }

  companion object {
    const val CHANNEL = "temanku/navigation"
    const val ACTION_OPEN_VOICE_TRANSACTION =
      "com.temanlabs.temanku.OPEN_VOICE_TRANSACTION"
    const val EXTRA_OPEN_VOICE_TRANSACTION = "open_voice_transaction"
    const val OPEN_VOICE_TRANSACTION = "open_voice_transaction"
  }
}
