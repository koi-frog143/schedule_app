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
                val instructor = widgetData.getString("widget_instructor", "") ?: ""
                val room = widgetData.getString("widget_room", "") ?: ""
                val timeRange = widgetData.getString("widget_time", "Free Time") ?: "Free Time"
                val startTime = widgetData.getString("widget_start_time", "00:00") ?: "00:00"
                val endTime = widgetData.getString("widget_end_time", "00:00") ?: "00:00"
                val imagePath = widgetData.getString("widget_image_path", null)
                val isActive = widgetData.getBoolean("widget_is_active", false)
                val progress = widgetData.getInt("widget_progress", 0).coerceIn(0, 100)

                val subtitle = when {
                    title == "No Class" -> "Free Time"
                    instructor.isNotEmpty() && room.isNotEmpty() -> "$instructor • $room"
                    instructor.isNotEmpty() -> instructor
                    room.isNotEmpty() -> room
                    else -> timeRange
                }

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_room, subtitle)
                setTextViewText(R.id.widget_start_time, startTime)
                setTextViewText(R.id.widget_end_time, endTime)
                setProgressBar(R.id.widget_progress, 100, progress, false)

                // Status indicator
                setViewVisibility(
                    R.id.widget_status_dot_active,
                    if (isActive) View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.widget_status_dot_inactive,
                    if (isActive) View.GONE else View.VISIBLE
                )

                // Subject profile picture from gallery
                var imageLoaded = false
                if (!imagePath.isNullOrEmpty()) {
                    try {
                        val file = File(imagePath)
                        if (file.exists()) {
                            val bitmap = decodeScaledBitmap(file.absolutePath)
                            if (bitmap != null) {
                                val rounded = getRoundedCornerBitmap(bitmap, 12f)
                                setImageViewBitmap(R.id.widget_image, rounded)
                                setViewVisibility(R.id.widget_image, View.VISIBLE)
                                setViewVisibility(R.id.widget_default_icon, View.GONE)
                                bitmap.recycle()
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

    private fun decodeScaledBitmap(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (bounds.outWidth / sampleSize > MAX_WIDGET_IMAGE_SIZE * 2 ||
            bounds.outHeight / sampleSize > MAX_WIDGET_IMAGE_SIZE * 2
        ) {
            sampleSize *= 2
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(path, options)
    }

    private fun getRoundedCornerBitmap(bitmap: Bitmap, cornerRadius: Float): Bitmap {
        val cropSize = minOf(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(
            MAX_WIDGET_IMAGE_SIZE,
            MAX_WIDGET_IMAGE_SIZE,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(output)
        val paint = Paint().apply {
            isAntiAlias = true
            color = -0x1
        }
        val rect = Rect(0, 0, MAX_WIDGET_IMAGE_SIZE, MAX_WIDGET_IMAGE_SIZE)
        val rectF = RectF(rect)

        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        val srcRect = if (bitmap.width >= bitmap.height) {
            val startX = (bitmap.width - bitmap.height) / 2
            Rect(startX, 0, startX + cropSize, cropSize)
        } else {
            val startY = (bitmap.height - bitmap.width) / 2
            Rect(0, startY, cropSize, startY + cropSize)
        }

        canvas.drawBitmap(bitmap, srcRect, rect, paint)
        return output
    }

    companion object {
        private const val MAX_WIDGET_IMAGE_SIZE = 160
    }
}
