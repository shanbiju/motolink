package com.motolink.app.motolink

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.motolink.app/media"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    val granted = MotoLinkMediaListenerService.isNotificationAccessGranted(this)
                    result.success(granted)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "getLastTrack" -> {
                    val data = mapOf(
                        "title" to MotoLinkMediaListenerService.lastTrackTitle,
                        "artist" to MotoLinkMediaListenerService.lastArtist,
                        "isPlaying" to MotoLinkMediaListenerService.lastIsPlaying
                    )
                    result.success(data)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MotoLinkMediaListenerService.onMediaUpdateCallback = { title, artist, isPlaying, source ->
            runOnUiThread {
                methodChannel?.invokeMethod(
                    "onMediaTrackReceived",
                    mapOf(
                        "title" to title,
                        "artist" to artist,
                        "isPlaying" to isPlaying,
                        "source" to source
                    )
                )
            }
        }
    }
}
