package com.martinbartko.nofeed

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Local notifications: the sender and the preview text of a new message, read
 * from Instagram's inbox list (see lib/unread_notifier.dart). Nothing is
 * stored or sent anywhere.
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

    /**
     * One notification per chat ([tag]): a newer message of the same chat
     * replaces the older one. On a locked screen with "hide sensitive content"
     * only "Nová správa" is shown (VISIBILITY_PRIVATE + public version).
     */
    fun showMessage(context: Context, title: String, body: String, tag: String?) {
        ensureChannels(context)
        val public = builder(context, CHANNEL_MESSAGES)
            .setContentTitle("NoFeed")
            .setContentText("Nová správa")
            .build()
        val notification = builder(context, CHANNEL_MESSAGES)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(public)
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(tag ?: "unread", ID_MESSAGES, notification)
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
