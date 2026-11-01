package com.incline.incline_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class InclineNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type") ?: "reminder"
        val title = intent.getStringExtra("title") ?: when (type) {
            "reminder" -> "Incline Club • Consistency Reminder"
            "motivation" -> "Daily Incline Motivation • Coach Bhagirath"
            "booking" -> "Booking Confirmed: Sub-Zero Cold Plunge"
            else -> "Incline Luxury Club"
        }
        val message = intent.getStringExtra("message") ?: when (type) {
            "reminder" -> "Missed yesterday's workout? \"The only bad workout is the one that didn't happen.\" Coach Bhagirath has loaded today's routine."
            "motivation" -> "\"The barbell doesn't care about your bad day. Neither should you.\" — Consistency separates the dedicated from the rest."
            "booking" -> "Your Sub-Zero Cold Plunge & Sauna Suite is confirmed for Saturday at 9:00 AM. Private contrast suite prepared."
            else -> "Rise. Reflect. Repeat."
        }

        val channelId = "incline_club_alerts"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Incline Club Alerts & Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Motivational cues, session reminders, and contrast suite bookings"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
    }
}
