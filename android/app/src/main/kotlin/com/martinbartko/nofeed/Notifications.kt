package com.martinbartko.nofeed

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Local notifications. Their text never contains names or message content –
 * only Instagram's unread counter (see lib/unread_notifier.dart).
 */
object Notifications {
    private const val CHANNEL_MESSAGES = "messages"
    private const val CHANNEL_KEEP_ALIVE = "keep_alive"
    private const val ID_MESSAGES = 1
    const val ID_KEEP_ALIVE = 2

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_MESSAGES, "Nové správy", NotificationManager.IMPORTANCE_HIGH),
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_KEEP_ALIVE,
                "NoFeed beží na pozadí",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { setShowBadge(false) },
        )
    }

    fun showMessage(context: Context, title: String, body: String) {
        ensureChannels(context)
        val notification = builder(context, CHANNEL_MESSAGES)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(ID_MESSAGES, notification)
    }

    fun keepAlive(context: Context): Notification {
        ensureChannels(context)
        return builder(context, CHANNEL_KEEP_ALIVE)
            .setContentTitle("NoFeed")
            .setContentText("Beží na pozadí, aby ti mohol oznámiť nové správy.")
            .setOngoing(true)
            .build()
    }

    private fun builder(context: Context, channel: String): Notification.Builder {
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder.setSmallIcon(R.drawable.ic_stat_nofeed).setContentIntent(open)
    }
}
