package com.motolink.app.motolink

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class MotoLinkMediaListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "MotoLinkMediaListener"
        var onMediaUpdateCallback: ((title: String, artist: String, isPlaying: Boolean, source: String) -> Unit)? = null
        var lastTrackTitle: String = ""
        var lastArtist: String = ""
        var lastIsPlaying: Boolean = false

        fun isNotificationAccessGranted(context: Context): Boolean {
            val packageName = context.packageName
            val flat = android.provider.Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            return flat != null && flat.contains(packageName)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener connected for MotoLink cluster sync")
        scanActiveMediaNotifications()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        sbn?.let { extractMediaFromNotification(it) }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }

    fun scanActiveMediaNotifications() {
        try {
            val activeNotifications = activeNotifications ?: return
            for (sbn in activeNotifications) {
                if (extractMediaFromNotification(sbn)) {
                    break
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scanning notifications: ${e.message}")
        }
    }

    private fun extractMediaFromNotification(sbn: StatusBarNotification): Boolean {
        val notification = sbn.notification ?: return false
        val extras: Bundle = notification.extras ?: return false

        val isMediaCategory = notification.category == Notification.CATEGORY_TRANSPORT
        val hasMediaSession = extras.containsKey(Notification.EXTRA_MEDIA_SESSION)
        val pkg = sbn.packageName.lowercase()

        val isMusicApp = pkg.contains("spotify") ||
                pkg.contains("music") ||
                pkg.contains("youtube") ||
                pkg.contains("wynk") ||
                pkg.contains("gaana") ||
                pkg.contains("jiosaavn") ||
                pkg.contains("soundcloud") ||
                pkg.contains("pandora") ||
                pkg.contains("deezer") ||
                pkg.contains("apple") ||
                pkg.contains("audio") ||
                pkg.contains("player")

        if (!isMediaCategory && !hasMediaSession && !isMusicApp) {
            return false
        }

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim()

        if (title.isNullOrEmpty()) {
            return false
        }

        val artist = when {
            !text.isNullOrEmpty() -> text
            !subText.isNullOrEmpty() -> subText
            else -> "Media Player"
        }

        // Check if playback is ongoing (actions often contain pause icon when playing)
        var isPlaying = true
        if (notification.actions != null) {
            for (action in notification.actions) {
                val actionTitle = action.title?.toString()?.lowercase() ?: ""
                if (actionTitle.contains("pause")) {
                    isPlaying = true
                    break
                } else if (actionTitle.contains("play")) {
                    isPlaying = false
                }
            }
        }

        if (title != lastTrackTitle || artist != lastArtist || isPlaying != lastIsPlaying) {
            lastTrackTitle = title
            lastArtist = artist
            lastIsPlaying = isPlaying
            Log.d(TAG, "Extracted track: '$title' by '$artist' (isPlaying: $isPlaying) from $pkg")

            onMediaUpdateCallback?.invoke(title, artist, isPlaying, pkg)
            return true
        }

        return false
    }
}
