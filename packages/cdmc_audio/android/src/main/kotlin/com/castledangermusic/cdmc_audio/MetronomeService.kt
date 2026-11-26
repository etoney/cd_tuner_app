package com.castledangermusic.cdmc_audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps the app alive while the metronome plays with the screen off, and
 * shows a notification with a Stop button on the lock screen.
 */
class MetronomeService : Service() {
    companion object {
        const val ACTION_SHOW = "cdmc.metronome.SHOW"
        const val ACTION_STOP = "cdmc.metronome.STOP"
        const val EXTRA_BPM = "bpm"
        private const val CHANNEL = "cdmc_metronome"
        private const val ID = 4711

        fun show(ctx: Context, bpm: Double) {
            val i = Intent(ctx, MetronomeService::class.java).setAction(ACTION_SHOW).putExtra(EXTRA_BPM, bpm)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun hide(ctx: Context) {
            ctx.stopService(Intent(ctx, MetronomeService::class.java))
        }
    }

    private var wake: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            AudioEngine.stopMetronome()
            stopSelf()
            return START_NOT_STICKY
        }
        val bpm = intent?.getDoubleExtra(EXTRA_BPM, 120.0) ?: 120.0
        val type = if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK else 0
        ServiceCompat.startForeground(this, ID, build(bpm), type)
        if (wake == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "cdmc:metronome").apply {
                setReferenceCounted(false)
                acquire(6 * 60 * 60 * 1000L)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wake?.let { if (it.isHeld) it.release() }
        wake = null
        super.onDestroy()
    }

    private fun build(bpm: Double): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Metronome", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shown while the metronome is playing"
                    setShowBadge(false)
                }
            )
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val stop = PendingIntent.getService(
            this, 1, Intent(this, MetronomeService::class.java).setAction(ACTION_STOP), flags
        )
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 2, it, flags)
        }
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Metronome")
            .setContentText("${bpm.toInt()} BPM")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(launch)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stop)
            .build()
    }
}
