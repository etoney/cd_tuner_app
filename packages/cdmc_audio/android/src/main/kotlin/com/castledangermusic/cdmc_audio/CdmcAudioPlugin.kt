package com.castledangermusic.cdmc_audio

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class CdmcAudioPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var pitchChannel: EventChannel
    private lateinit var beatChannel: EventChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingMic: MethodChannel.Result? = null
    private var askedNotifications = false

    companion object { private const val REQ_MIC = 4712; private const val REQ_NOTIFY = 4713 }

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "cdmc_audio")
        channel.setMethodCallHandler(this)
        pitchChannel = EventChannel(b.binaryMessenger, "cdmc_audio/pitch")
        pitchChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { AudioEngine.onPitch = { sink.success(it) } }
            override fun onCancel(args: Any?) { AudioEngine.onPitch = null }
        })
        beatChannel = EventChannel(b.binaryMessenger, "cdmc_audio/beat")
        beatChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { AudioEngine.onBeat = { sink.success(it) } }
            override fun onCancel(args: Any?) { AudioEngine.onBeat = null }
        })
        AudioEngine.onMetronomeState = { playing, bpm ->
            if (playing) MetronomeService.show(context, bpm) else MetronomeService.hide(context)
        }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        pitchChannel.setStreamHandler(null)
        beatChannel.setStreamHandler(null)
        AudioEngine.stopTuner()
        AudioEngine.stopTone()
        AudioEngine.stopMetronome()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTuner" -> {
                if (hasMic()) { AudioEngine.startTuner(); result.success(true) }
                else {
                    val act = activity
                    if (act == null) { result.success(false); return }
                    pendingMic?.success(false)
                    pendingMic = result
                    ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.RECORD_AUDIO), REQ_MIC)
                }
            }
            "stopTuner" -> { AudioEngine.stopTuner(); result.success(null) }
            "keepAwake" -> {
                val on = call.argument<Boolean>("on") ?: false
                activity?.window?.let { w ->
                    if (on) w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else w.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
            "startTone" -> { AudioEngine.startTone(call.argument<Double>("hz") ?: 440.0); result.success(null) }
            "stopTone" -> { AudioEngine.stopTone(); result.success(null) }
            "pluck" -> { AudioEngine.pluck(call.argument<Double>("hz") ?: 440.0); result.success(null) }
            "previewSound" -> { AudioEngine.previewSound(call.argument<Int>("sound") ?: 0); result.success(null) }
            "setMetronome" -> {
                val playing = call.argument<Boolean>("playing") ?: false
                if (playing) askNotifications()
                AudioEngine.setMetronome(
                    call.argument<Double>("bpm") ?: 120.0,
                    (call.argument<List<Int>>("beats") ?: listOf(3, 2, 2, 2)).toIntArray(),
                    call.argument<Int>("subdivision") ?: 1,
                    call.argument<Int>("sound") ?: 0,
                    playing,
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasMic() =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    /** Android 13+: ask once so the lock-screen Stop button can be shown. */
    private fun askNotifications() {
        if (askedNotifications || Build.VERSION.SDK_INT < 33) return
        val act = activity ?: return
        askedNotifications = true
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFY)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQ_MIC) {
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (ok) AudioEngine.startTuner()
            pendingMic?.success(ok)
            pendingMic = null
            return true
        }
        return requestCode == REQ_NOTIFY
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity; binding = b; b.addRequestPermissionsResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() { onDetachedFromActivity() }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) { onAttachedToActivity(b) }
    override fun onDetachedFromActivity() {
        binding?.removeRequestPermissionsResultListener(this); binding = null; activity = null
    }
}
