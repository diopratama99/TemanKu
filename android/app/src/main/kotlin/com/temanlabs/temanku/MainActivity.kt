package com.temanlabs.temanku

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var navigationChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Cache the engine so TemanKuNotificationListener can access it
    FlutterEngineCache.getInstance().put("main_engine", flutterEngine)
    navigationChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      CHANNEL,
    )
    navigationChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "getInitialAction" -> {
          val action = extractLaunchAction(intent)
          // Clear intent so it won't be re-processed on resume
          clearLaunchIntent()
          result.success(action)
        }
        else -> result.notImplemented()
      }
    }

    // Notification channel — handles openNotificationSettings + local notifs
    val notifChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      NOTIF_CHANNEL,
    )
    notifChannel.setMethodCallHandler { call, result ->
      when (call.method) {
        "openNotificationSettings" -> {
          val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
          startActivity(intent)
          result.success(null)
        }
        "showLocalNotification" -> {
          val title = call.argument<String>("title") ?: "TemanKu"
          val body = call.argument<String>("body") ?: ""
          val action = call.argument<String>("action")
          showLocalNotification(title, body, action)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    val action = extractLaunchAction(intent) ?: return
    // Clear immediately so app resume won't re-fire
    clearLaunchIntent()
    if (action == OPEN_VOICE_TRANSACTION) {
      navigationChannel?.invokeMethod("openVoiceTransaction", null)
    } else if (action == OPEN_CAMERA_TRANSACTION) {
      navigationChannel?.invokeMethod("openCameraTransaction", null)
    } else if (action == OPEN_HISTORY_TRANSACTION) {
      navigationChannel?.invokeMethod("openHistoryTransaction", null)
    } else if (action == OPEN_HISTORY_TRANSFER) {
      navigationChannel?.invokeMethod("openHistoryTransfer", null)
    }
  }

  private fun extractLaunchAction(intent: Intent?): String? {
    if (intent == null) return null
    return if (
      intent.action == ACTION_OPEN_VOICE_TRANSACTION ||
      intent.getBooleanExtra(EXTRA_OPEN_VOICE_TRANSACTION, false)
    ) {
      OPEN_VOICE_TRANSACTION
    } else if (
      intent.action == ACTION_OPEN_CAMERA_TRANSACTION ||
      intent.getBooleanExtra(EXTRA_OPEN_CAMERA_TRANSACTION, false)
    ) {
      OPEN_CAMERA_TRANSACTION
    } else if (intent.action == ACTION_OPEN_HISTORY_TRANSACTION) {
      OPEN_HISTORY_TRANSACTION
    } else if (intent.action == ACTION_OPEN_HISTORY_TRANSFER) {
      OPEN_HISTORY_TRANSFER
    } else {
      null
    }
  }

  /// Strip all widget-launch extras and action from the current intent
  /// so that resuming the Activity (e.g. coming back from home screen)
  /// will not accidentally re-trigger the same navigation.
  private fun clearLaunchIntent() {
    intent?.apply {
      action = Intent.ACTION_MAIN
      removeExtra(EXTRA_OPEN_VOICE_TRANSACTION)
      removeExtra(EXTRA_OPEN_CAMERA_TRANSACTION)
      // Clear intent action if it was one of the history actions
      if (action == ACTION_OPEN_HISTORY_TRANSACTION || action == ACTION_OPEN_HISTORY_TRANSFER) {
        action = Intent.ACTION_MAIN
      }
    }
  }

  private var notifIdCounter = 1000

  private fun showLocalNotification(title: String, body: String, notifAction: String?) {
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val channelId = "temanku_auto_notif"

    // Create channel (required on Android O+)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        channelId,
        "Transaksi Otomatis",
        NotificationManager.IMPORTANCE_DEFAULT
      ).apply {
        description = "Notifikasi dari fitur baca notifikasi otomatis TemanKu"
      }
      nm.createNotificationChannel(channel)
    }

    val notificationIntent = Intent(this, MainActivity::class.java).apply {
      action = when (notifAction) {
        "transaction" -> ACTION_OPEN_HISTORY_TRANSACTION
        "transfer" -> ACTION_OPEN_HISTORY_TRANSFER
        else -> Intent.ACTION_MAIN
      }
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    
    val pendingIntent = PendingIntent.getActivity(
      this,
      notifIdCounter,
      notificationIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val notification = NotificationCompat.Builder(this, channelId)
      .setSmallIcon(R.mipmap.ic_launcher)
      .setContentTitle(title)
      .setContentText(body)
      .setContentIntent(pendingIntent)
      .setAutoCancel(true)
      .setPriority(NotificationCompat.PRIORITY_DEFAULT)
      .build()

    nm.notify(notifIdCounter++, notification)
  }

  companion object {
    const val CHANNEL = "temanku/navigation"
    const val NOTIF_CHANNEL = "temanku/notifications"
    const val ACTION_OPEN_VOICE_TRANSACTION =
      "com.temanlabs.temanku.OPEN_VOICE_TRANSACTION"
    const val EXTRA_OPEN_VOICE_TRANSACTION = "open_voice_transaction"
    const val OPEN_VOICE_TRANSACTION = "open_voice_transaction"

    const val ACTION_OPEN_CAMERA_TRANSACTION =
      "com.temanlabs.temanku.OPEN_CAMERA_TRANSACTION"
    const val EXTRA_OPEN_CAMERA_TRANSACTION = "open_camera_transaction"
    const val OPEN_CAMERA_TRANSACTION = "open_camera_transaction"

    const val ACTION_OPEN_HISTORY_TRANSACTION =
      "com.temanlabs.temanku.OPEN_HISTORY_TRANSACTION"
    const val OPEN_HISTORY_TRANSACTION = "open_history_transaction"

    const val ACTION_OPEN_HISTORY_TRANSFER =
      "com.temanlabs.temanku.OPEN_HISTORY_TRANSFER"
    const val OPEN_HISTORY_TRANSFER = "open_history_transfer"
  }
}
