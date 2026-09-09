package com.example.schedule_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.schedule_widget).apply {
                val title = widgetData.getString("widget_title", "No Class") ?: "No Class"
                val room = widgetData.getString("widget_room", "") ?: ""
                val timeRange = widgetData.getString("widget_time", "Free Time") ?: "Free Time"
                val startTime = widgetData.getString("widget_start_time", "00:00") ?: "00:00"
                val endTime = widgetData.getString("widget_end_time", "00:00") ?: "00:00"
                val imagePath = widgetData.getString("widget_image_path", null)
                val isActive = widgetData.getBoolean("widget_is_active", false)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(
                    R.id.widget_room,
                    if (room.isNotEmpty()) room else timeRange
                )
                setTextViewText(R.id.widget_start_time, startTime)
                setTextViewText(R.id.widget_end_time, endTime)

                // Status indicator
                setViewVisibility(
                    R.id.widget_status_dot_active,
                    if (isActive) View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.widget_status_dot_inactive,
                    if (isActive) View.GONE else View.VISIBLE
                )
                setTextViewText(
                    R.id.widget_status_label,
                    if (isActive) "NOW ACTIVE" else "UPCOMING"
                )

                // Subject profile picture from gallery
                var imageLoaded = false
                if (!imagePath.isNullOrEmpty()) {
                    try {
                        val file = File(imagePath)
                        if (file.exists()) {
                            val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                            if (bitmap != null) {
                                val rounded = getRoundedCornerBitmap(bitmap, 20f)
                                setImageViewBitmap(R.id.widget_image, rounded)
                                setViewVisibility(R.id.widget_image, View.VISIBLE)
                                setViewVisibility(R.id.widget_default_icon, View.GONE)
                                imageLoaded = true
                            }
                        }
                    } catch (_: Exception) {
                        imageLoaded = false
                    }
                }

                if (!imageLoaded) {
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.widget_default_icon, View.VISIBLE)
                }

                // Launch app on widget tap
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun getRoundedCornerBitmap(bitmap: Bitmap, cornerRadius: Float): Bitmap {
        val size = Math.min(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint().apply {
            isAntiAlias = true
            color = -0x1
        }
        val rect = Rect(0, 0, size, size)
        val rectF = RectF(rect)

        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        val srcRect = if (bitmap.width >= bitmap.height) {
            val startX = (bitmap.width - bitmap.height) / 2
            Rect(startX, 0, startX + size, size)
        } else {
            val startY = (bitmap.height - bitmap.width) / 2
            Rect(0, startY, size, startY + size)
        }

        canvas.drawBitmap(bitmap, srcRect, rect, paint)
        return output
    }
}