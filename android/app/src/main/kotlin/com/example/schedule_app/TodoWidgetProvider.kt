package com.example.schedule_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

abstract class BaseTodoWidgetProvider(
    private val maximumItems: Int
) : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val items = readItems(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.todo_widget)
            val visibleItems = items.take(maximumItems)
            val incompleteCount = items.count { !it.isCompleted }

            views.setTextViewText(R.id.todo_count, incompleteCount.toString())

            if (visibleItems.isEmpty()) {
                showEmptyState(views)
            } else {
                TODO_ROWS.forEachIndexed { index, row ->
                    val item = visibleItems.getOrNull(index)
                    if (item == null || index >= maximumItems) {
                        views.setViewVisibility(row.containerId, View.GONE)
                    } else {
                        views.setViewVisibility(row.containerId, View.VISIBLE)
                        views.setViewVisibility(row.checkboxId, View.VISIBLE)
                        views.setTextViewText(row.textId, item.title)
                        views.setTextColor(
                            row.textId,
                            if (item.isCompleted) COMPLETED_TEXT_COLOR else ACTIVE_TEXT_COLOR
                        )
                        views.setImageViewResource(
                            row.checkboxId,
                            if (item.isCompleted) {
                                R.drawable.todo_checkbox_checked
                            } else {
                                R.drawable.todo_checkbox_unchecked
                            }
                        )
                    }
                }
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.todo_widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun showEmptyState(views: RemoteViews) {
        TODO_ROWS.forEachIndexed { index, row ->
            if (index == 0) {
                views.setViewVisibility(row.containerId, View.VISIBLE)
                views.setViewVisibility(row.checkboxId, View.VISIBLE)
                views.setImageViewResource(
                    row.checkboxId,
                    R.drawable.todo_checkbox_unchecked
                )
                views.setTextViewText(row.textId, "No to-do items yet")
                views.setTextColor(row.textId, COMPLETED_TEXT_COLOR)
            } else {
                views.setViewVisibility(row.containerId, View.GONE)
            }
        }
    }

    private fun readItems(widgetData: SharedPreferences): List<TodoWidgetItem> {
        val json = widgetData.getString(TODO_ITEMS_KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(json)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val title = item.optString("title").trim()
                    if (title.isNotEmpty()) {
                        add(
                            TodoWidgetItem(
                                title = title,
                                isCompleted = item.optBoolean("isCompleted", false)
                            )
                        )
                    }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private data class TodoWidgetItem(
        val title: String,
        val isCompleted: Boolean
    )

    private data class TodoRow(
        val containerId: Int,
        val checkboxId: Int,
        val textId: Int
    )

    companion object {
        private const val TODO_ITEMS_KEY = "widget_todo_items"
        private val ACTIVE_TEXT_COLOR = Color.rgb(48, 48, 48)
        private val COMPLETED_TEXT_COLOR = Color.rgb(135, 135, 135)

        private val TODO_ROWS = listOf(
            TodoRow(R.id.todo_row_1, R.id.todo_checkbox_1, R.id.todo_text_1),
            TodoRow(R.id.todo_row_2, R.id.todo_checkbox_2, R.id.todo_text_2),
            TodoRow(R.id.todo_row_3, R.id.todo_checkbox_3, R.id.todo_text_3),
            TodoRow(R.id.todo_row_4, R.id.todo_checkbox_4, R.id.todo_text_4),
            TodoRow(R.id.todo_row_5, R.id.todo_checkbox_5, R.id.todo_text_5),
            TodoRow(R.id.todo_row_6, R.id.todo_checkbox_6, R.id.todo_text_6),
            TodoRow(R.id.todo_row_7, R.id.todo_checkbox_7, R.id.todo_text_7),
            TodoRow(R.id.todo_row_8, R.id.todo_checkbox_8, R.id.todo_text_8)
        )
    }
}

class TodoWidgetFourProvider : BaseTodoWidgetProvider(maximumItems = 4)

class TodoWidgetEightProvider : BaseTodoWidgetProvider(maximumItems = 8)
