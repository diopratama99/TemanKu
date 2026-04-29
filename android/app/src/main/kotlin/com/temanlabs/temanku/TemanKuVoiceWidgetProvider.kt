package com.temanlabs.temanku

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class TemanKuVoiceWidgetProvider : AppWidgetProvider() {
  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
  ) {
    appWidgetIds.forEach { appWidgetId ->
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    refreshAll(context)
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (
      intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
      intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
    ) {
      refreshAll(context)
    }
  }

  companion object {
    private fun launchPendingIntent(context: Context): PendingIntent {
      val intent = Intent(context, MainActivity::class.java).apply {
        action = MainActivity.ACTION_OPEN_VOICE_TRANSACTION
        putExtra(MainActivity.EXTRA_OPEN_VOICE_TRANSACTION, true)
        flags =
          Intent.FLAG_ACTIVITY_NEW_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
            Intent.FLAG_ACTIVITY_SINGLE_TOP
      }
      return PendingIntent.getActivity(
        context,
        4001,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }

    fun updateAppWidget(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
    ) {
      val views = RemoteViews(context.packageName, R.layout.temanku_voice_widget)
      val pendingIntent = launchPendingIntent(context)
      views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
      views.setOnClickPendingIntent(R.id.widget_mic, pendingIntent)
      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun refreshAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val component = ComponentName(context, TemanKuVoiceWidgetProvider::class.java)
      val ids = manager.getAppWidgetIds(component)
      ids.forEach { updateAppWidget(context, manager, it) }
    }
  }
}
