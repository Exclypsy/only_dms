package com.martinbartko.nofeed

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps NoFeed's process (and so the open Instagram page) running while the
 * app is in the background, like a browser tab left open, so Instagram's own
 * unread counter keeps updating. Shows a permanent low-priority notification,
 * as Android requires. No extra requests are made to Instagram.
 */
class KeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = Notifications.keepAlive(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                Notifications.ID_KEEP_ALIVE,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING,
            )
        } else {
            startForeground(Notifications.ID_KEEP_ALIVE, notification)
        }
        // Without the app's page there is nothing to keep alive: don't restart.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App swiped away from recents: the page is gone, stop as well.
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
}
