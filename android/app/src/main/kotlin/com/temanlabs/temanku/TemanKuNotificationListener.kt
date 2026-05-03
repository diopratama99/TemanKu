package com.temanlabs.temanku

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Listens for notifications from financial apps (e-wallets & banking)
 * and forwards the text content to Flutter via MethodChannel.
 *
 * Only packages in [MONITORED_PACKAGES] are forwarded — all others
 * are silently ignored to protect user privacy.
 */
class TemanKuNotificationListener : NotificationListenerService() {

  companion object {
    const val CHANNEL = "temanku/notifications"

    /** Package names of financial apps we monitor. */
    val MONITORED_PACKAGES = setOf(
      // E-Wallets
      "id.dana",
      "com.gojek.app",
      "com.gojek.gopay",
      "com.ovo.fif",
      "com.shopee.id",
      "com.telkom.mwallet",           // LinkAja
      // Banking — Konvensional
      "com.bca",
      "com.bca.mBCA",
      "com.bca.mybca",
      "id.co.bri.brimobile",
      "id.bmri.livin",
      "com.bni.mobilebanking",
      "id.bni.wondr",                 // Wondr by BNI
      "net.id.permatabank.permatamobile", // PermataMobile X
      "id.co.cimbniaga.mobile.android",  // Octo Mobile (CIMB Niaga)
      // Banking — Digital
      "com.jago.retailApp",           // Bank Jago
      "com.bke.seabank",              // SeaBank
      "com.btpn.dc.jeniusapp",        // Jenius (BTPN)
      "com.bcadigital.blu",           // blu by BCA Digital
      "co.id.ncb",                    // Neobank (BNC)
      "id.koala.app",                 // Allo Bank
      "id.co.superbank",              // Superbank
    )

    // Simple dedup: track last N notification keys to avoid re-processing
    // the same notification when it gets updated.
    private val recentKeys = LinkedHashSet<String>()
    private const val MAX_RECENT = 50
  }

  override fun onNotificationPosted(sbn: StatusBarNotification?) {
    if (sbn == null) return
    val pkg = sbn.packageName ?: return

    if (pkg !in MONITORED_PACKAGES) return

    // Dedup: create a key from package + tag + id + post time (rounded to 5s)
    val roundedTime = (sbn.postTime / 5000) * 5000
    val dedupKey = "$pkg|${sbn.tag}|${sbn.id}|$roundedTime"
    synchronized(recentKeys) {
      if (recentKeys.contains(dedupKey)) return
      recentKeys.add(dedupKey)
      // Evict oldest if over limit
      while (recentKeys.size > MAX_RECENT) {
        val iter = recentKeys.iterator()
        iter.next()
        iter.remove()
      }
    }

    val extras: Bundle = sbn.notification?.extras ?: return

    // Extract text from notification
    val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
    val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
    val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

    // Use bigText if available (more detail), fallback to text
    val body = bigText.ifBlank { text }
    if (body.isBlank() && title.isBlank()) return

    val notificationText = if (title.isNotBlank() && body.isNotBlank()) {
      "$title: $body"
    } else {
      title.ifBlank { body }
    }

    // Forward to Flutter
    val engine = FlutterEngineCache.getInstance().get("main_engine")
    if (engine != null) {
      val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
      val data = mapOf(
        "notification_text" to notificationText,
        "package_name" to pkg,
        "timestamp" to sbn.postTime,
      )
      // Must invoke on main thread
      android.os.Handler(android.os.Looper.getMainLooper()).post {
        channel.invokeMethod("onNotificationReceived", data)
      }
    }
  }

  override fun onNotificationRemoved(sbn: StatusBarNotification?) {
    // No-op: we only care about posted notifications
  }
}
