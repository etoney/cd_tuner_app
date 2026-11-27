package com.castledangermusic.cdmc_audio

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max

/**
 * One output stream mixes the metronome clicks, the reference tone and
 * plucked notes. Clicks are placed at exact sample positions inside the
 * render loop, so tempo is rock steady and does not depend on the UI.
 */
object AudioEngine {
    private const val SR = 48000
    private const val BLOCK = 256

    var onBeat: ((Int) -> Unit)? = null
    var onPitch: ((Double) -> Unit)? = null
    /** Called on the main thread whenever the metronome starts or stops. */
    var onMetronomeState: ((Boolean, Double) -> Unit)? = null

    private val main = Handler(Looper.getMainLooper())

    // ---- metronome settings (written from the main thread, read by the audio thread)
    @Volatile private var bpm = 120.0
    @Volatile private var beats = intArrayOf(3, 2, 2, 2)
    @Volatile private var subdivision = 1
    @Volatile private var sound = 0
    @Volatile var metronomeOn = false
        private set
    @Volatile private var restart = false

    // ---- tone
    @Volatile private var toneHz = 0.0
    @Volatile private var toneOn = false

    // ---- one-shot voices (clicks, previews, plucks)
    private class Voice(val buf: FloatArray) { var pos = 0 }
    private val pending = java.util.concurrent.ConcurrentLinkedQueue<FloatArray>()

    @Volatile private var outRunning = false
    private var outThread: Thread? = null

    // ---------------------------------------------------------------- metronome
    fun setMetronome(bpm: Double, beats: IntArray, subdivision: Int, sound: Int, playing: Boolean) {
        this.bpm = bpm.coerceIn(20.0, 400.0)
        this.beats = if (beats.isEmpty()) intArrayOf(3) else beats
        this.subdivision = subdivision.coerceIn(1, 8)
        this.sound = sound.coerceIn(0, Sounds.names.size - 1)
        if (playing && !metronomeOn) {
            restart = true
            metronomeOn = true
            ensureOutput()
            main.post { onMetronomeState?.invoke(true, this.bpm) }
        } else if (!playing && metronomeOn) {
            stopMetronome()
        } else if (metronomeOn) {
            main.post { onMetronomeState?.invoke(true, this.bpm) }
        }
    }

    fun stopMetronome() {
        if (!metronomeOn) return
        metronomeOn = false
        main.post {
            onBeat?.invoke(-1)
            onMetronomeState?.invoke(false, bpm)
        }
    }

    fun previewSound(sound: Int) {
        pending.add(Sounds.buffers(SR)[sound.coerceIn(0, Sounds.names.size - 1)][3])
        ensureOutput()
    }

    fun pluck(hz: Double) {
        pending.add(Sounds.pluck(hz, SR))
        ensureOutput()
    }

    fun startTone(hz: Double) {
        toneHz = hz
        toneOn = true
        ensureOutput()
    }

    fun stopTone() { toneOn = false }

    private fun ensureOutput() {
        if (outRunning) return
        outRunning = true
        outThread = Thread({ outputLoop() }, "cdmc-audio-out").apply {
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    private fun outputLoop() {
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
        val minBuf = AudioTrack.getMinBufferSize(SR, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(SR)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(max(minBuf, BLOCK * 4 * 4))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        track.play()

        val bufs = Sounds.buffers(SR)
        val voices = ArrayList<Voice>(16)
        val block = FloatArray(BLOCK)
        var clock = 0L
        var nextTick = 0.0
        var step = 0L
        var tonePhase = 0.0
        var toneGain = 0.0
        var idle = 0
        val latencyMs = ((track.bufferSizeInFrames + BLOCK) * 1000L / SR)

        while (outRunning) {
            while (true) { val b = pending.poll() ?: break; voices.add(Voice(b)) }
            if (restart) {
                restart = false
                step = 0
                nextTick = (clock + SR / 20).toDouble()
            }
            val on = metronomeOn
            val sub = subdivision
            val pattern = beats
            val stepLen = SR * 60.0 / bpm / sub
            val tHz = toneHz
            val tTarget = if (toneOn) 0.18 else 0.0

            for (i in 0 until BLOCK) {
                if (on && clock + i >= nextTick) {
                    val beatIdx = ((step / sub) % pattern.size).toInt()
                    val level = pattern[beatIdx]
                    val isBeat = step % sub == 0L
                    if (level > 0) {
                        val kind = if (isBeat) level else 0
                        voices.add(Voice(bufs[sound][kind]))
                    }
                    if (isBeat) {
                        val delay = latencyMs + (i * 1000L / SR)
                        main.postDelayed({ if (metronomeOn) onBeat?.invoke(beatIdx) }, delay)
                    }
                    step++
                    nextTick += stepLen
                }
                var s = 0f
                val iter = voices.iterator()
                while (iter.hasNext()) {
                    val v = iter.next()
                    if (v.pos >= v.buf.size) { iter.remove(); continue }
                    s += v.buf[v.pos++]
                }
                toneGain += (tTarget - toneGain) * 0.002
                if (toneGain > 0.0005) {
                    tonePhase += tHz / SR
                    if (tonePhase >= 1) tonePhase -= floor(tonePhase)
                    s += (toneGain * (1 - 4 * abs(tonePhase - 0.5))).toFloat()
                }
                block[i] = s.coerceIn(-1f, 1f)
            }
            clock += BLOCK
            track.write(block, 0, BLOCK, AudioTrack.WRITE_BLOCKING)

            // Shut the stream down after ~2 s of silence to save battery.
            idle = if (!metronomeOn && !toneOn && voices.isEmpty() && pending.isEmpty() && toneGain < 0.0005) idle + 1 else 0
            if (idle > SR * 2 / BLOCK) outRunning = false
        }
        track.stop()
        track.release()
        // A new request may have arrived while we were shutting down.
        if (metronomeOn || toneOn || pending.isNotEmpty()) main.post { ensureOutput() }
    }

    // -------------------------------------------------------------------- tuner
    @Volatile private var inRunning = false
    private var inThread: Thread? = null

    @SuppressLint("MissingPermission")
    fun startTuner() {
        if (inRunning) return
        inRunning = true
        inThread = Thread({
            val rate = 48000
            val chunk = 1024
            val minBuf = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            val source = if (Build.VERSION.SDK_INT >= 24) MediaRecorder.AudioSource.UNPROCESSED else MediaRecorder.AudioSource.VOICE_RECOGNITION
            var rec = AudioRecord(source, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, max(minBuf, chunk * 8))
            if (rec.state != AudioRecord.STATE_INITIALIZED) {
                rec.release()
                rec = AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, max(minBuf, chunk * 8))
            }
            val tracker = PitchTracker(rate)
            val shorts = ShortArray(chunk)
            rec.startRecording()
            while (inRunning) {
                val n = rec.read(shorts, 0, chunk)
                if (n <= 0) continue
                for (i in 0 until n) {
                    tracker.push(shorts[i] / 32768f)
                    if (tracker.due()) {
                        val hz = tracker.detect()
                        main.post { onPitch?.invoke(hz) }
                    }
                }
            }
            rec.stop()
            rec.release()
        }, "cdmc-audio-in").apply { start() }
    }

    fun stopTuner() { inRunning = false }
}
