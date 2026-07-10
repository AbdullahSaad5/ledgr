package com.abdullahsaad5.ledgr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Overview widget: net worth, this month's spent/received, overall budget
 * progress, the two most recent transactions, and a quick-add button that
 * deep-links into the keypad (ledgr://add).
 */
class LedgrWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ledgr_widget).apply {
                setTextViewText(
                    R.id.widget_net_worth,
                    prefs.getString("net_worth", "Rs 0"),
                )
                setTextViewText(R.id.widget_period, prefs.getString("period_label", ""))
                setTextViewText(
                    R.id.widget_spent,
                    "↓ " + prefs.getString("spent", "Rs 0") + " spent",
                )
                setTextViewText(
                    R.id.widget_received,
                    "↑ " + prefs.getString("received", "Rs 0") + " in",
                )

                val budgetPct = prefs.getInt("budget_pct", -1)
                if (budgetPct >= 0) {
                    setViewVisibility(R.id.widget_budget_row, View.VISIBLE)
                    setTextViewText(
                        R.id.widget_budget_label,
                        prefs.getString("budget_label", "Budget"),
                    )
                    setProgressBar(R.id.widget_budget_bar, 100, budgetPct, false)
                } else {
                    setViewVisibility(R.id.widget_budget_row, View.GONE)
                }

                val tx1 = prefs.getString("tx1_title", "") ?: ""
                if (tx1.isEmpty()) {
                    setViewVisibility(R.id.widget_recent_row, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_recent_row, View.VISIBLE)
                    setTextViewText(R.id.widget_tx1_title, tx1)
                    setTextViewText(
                        R.id.widget_tx1_amount,
                        prefs.getString("tx1_amount", ""),
                    )
                    setTextViewText(
                        R.id.widget_tx2_title,
                        prefs.getString("tx2_title", ""),
                    )
                    setTextViewText(
                        R.id.widget_tx2_amount,
                        prefs.getString("tx2_amount", ""),
                    )
                }

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(R.id.widget_add, addIntent(context))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/** ACTION_VIEW into the keypad — handled by Flutter's own deep-linking. */
private fun addIntent(context: Context): PendingIntent {
    val intent = Intent(
        Intent.ACTION_VIEW,
        Uri.parse("ledgr:///tx/new"),
        context,
        MainActivity::class.java,
    )
    return PendingIntent.getActivity(
        context,
        1,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

/**
 * Compact quick-add widget: one tap into the keypad, with today's spend as
 * the subtitle.
 */
class LedgrQuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(
                context.packageName,
                R.layout.ledgr_quick_add_widget,
            ).apply {
                setTextViewText(
                    R.id.quick_today,
                    "Today: " + prefs.getString("today_spent", "Rs 0"),
                )
                setOnClickPendingIntent(R.id.quick_root, addIntent(context))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
