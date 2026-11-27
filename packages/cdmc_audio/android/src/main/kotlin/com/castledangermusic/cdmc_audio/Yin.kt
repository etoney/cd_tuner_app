package com.castledangermusic.cdmc_audio

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Pitch tracking for guitar and bass (about 27 Hz to 1400 Hz, so a
 * 5-string bass's low B0 at 30.87 Hz is covered).
 *
 * The microphone signal is first band-passed (25 Hz to 1.5 kHz) and
 * decimated by 4. That strips out hiss and room noise above the strings'
 * useful range, so quiet notes from a phone at arm's length still read
 * accurately. Then YIN finds the period. Same algorithm as Yin.swift on iOS.
 */
class PitchTracker(inputRate: Int) {
    private val decim = 4
    val rate = inputRate / decim
    private val lp1 = Biquad.lowPass(1500.0, inputRate.toDouble())
    private val lp2 = Biquad.lowPass(1500.0, inputRate.toDouble())
    private val hp = Biquad.highPass(25.0, inputRate.toDouble())
    private var phase = 0
    // ~340 ms window: long enough to keep a fading string readable.
    private val ring = FloatArray(4096)
    private val window = FloatArray(4096)
    private var pos = 0
    private var filled = 0
    private var sinceLast = 0

    /** The pitch we're locked onto, so a fading note stays tracked. */
    private var locked = -1.0
    private var misses = 0

    /** Feeds one raw microphone sample. */
    fun push(x: Float) {
        val y = hp.process(lp2.process(lp1.process(x)))
        if (++phase < decim) return
        phase = 0
        ring[pos] = y
        pos = (pos + 1) % ring.size
        if (filled < ring.size) filled++
        sinceLast++
    }

    /** True about ten times a second once the window is full. */
    fun due(): Boolean {
        if (filled < ring.size || sinceLast < rate / 10) return false
        sinceLast = 0
        return true
    }

    fun detect(): Double {
        // Unroll the circular buffer, oldest sample first.
        val tail = ring.size - pos
        System.arraycopy(ring, pos, window, 0, tail)
        System.arraycopy(ring, 0, window, tail, pos)
        val hz = Yin.track(window, rate, locked)
        if (hz > 0) { locked = hz; misses = 0 } else if (++misses >= 5) locked = -1.0
        return hz
    }
}

class Biquad private constructor(
    private val b0: Double, private val b1: Double, private val b2: Double,
    private val a1: Double, private val a2: Double,
) {
    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    fun process(x: Float): Float {
        val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x.toDouble(); y2 = y1; y1 = y
        return y.toFloat()
    }

    companion object {
        private const val Q = 0.7071

        fun lowPass(f: Double, sr: Double): Biquad {
            val w = 2 * PI * f / sr
            val c = cos(w)
            val a = sin(w) / (2 * Q)
            val a0 = 1 + a
            return Biquad((1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0, -2 * c / a0, (1 - a) / a0)
        }

        fun highPass(f: Double, sr: Double): Biquad {
            val w = 2 * PI * f / sr
            val c = cos(w)
            val a = sin(w) / (2 * Q)
            val a0 = 1 + a
            return Biquad((1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - a) / a0)
        }
    }
}

object Yin {
    private const val THRESHOLD = 0.15f
    private const val RELATIVE = 1.6f
    private const val STRONG = 0.35f      // clear pitch: accept anywhere
    private const val WEAK = 0.6f         // fading note: accept only near the locked pitch
    private const val MIN_RMS = 0.00015f  // essentially silence

    /**
     * Returns the fundamental in Hz, or -1 when there's no usable pitch.
     * [locked] is the last good reading (or -1): a fading note that is too
     * weak to find from scratch is still followed if it stays near it.
     */
    fun track(b: FloatArray, sampleRate: Int, locked: Double): Double {
        var sum = 0.0
        for (x in b) sum += x * x
        if (sqrt(sum / b.size) < MIN_RMS) return -1.0

        val minLag = sampleRate / 1400
        val maxLag = sampleRate / 27
        val w = b.size - maxLag - 2
        if (w <= 0) return -1.0
        val d = FloatArray(maxLag + 2)
        d[0] = 1f
        var run = 0.0
        for (t in 1..maxLag + 1) {
            var s = 0.0
            for (i in 0 until w) {
                val x = b[i] - b[i + t]
                s += x * x
            }
            run += s
            d[t] = if (run > 0) (s * t / run).toFloat() else 1f
        }

        // 1. Search from scratch: first dip that is nearly as good as the best.
        var gmin = Float.MAX_VALUE
        for (t in minLag until maxLag) if (d[t] < gmin) gmin = d[t]
        val limit = maxOf(THRESHOLD, gmin * RELATIVE)
        var tau = minLag
        while (tau < maxLag && d[tau] >= limit) tau++
        while (tau + 1 < maxLag && d[tau + 1] < d[tau]) tau++
        val free = refine(d, tau, sampleRate)
        val nearLock = locked > 0 && kotlin.math.abs(1200 * kotlin.math.ln(free / locked) / kotlin.math.ln(2.0)) < 300
        if (d[tau] < STRONG && (locked <= 0 || nearLock)) return free

        // 2. Follow the locked pitch within about ±60 cents.
        if (locked <= 0) return -1.0
        val p = sampleRate / locked
        val lo = maxOf(2, (p / 1.035).toInt())
        val hi = minOf(maxLag - 1, (p * 1.035).toInt() + 1)
        var best = lo
        for (t in lo..hi) if (d[t] < d[best]) best = t
        return if (d[best] < WEAK) refine(d, best, sampleRate) else -1.0
    }

    private fun refine(d: FloatArray, tau: Int, sampleRate: Int): Double {
        val a = d[tau - 1]
        val c = d[tau + 1]
        val den = a + c - 2 * d[tau]
        val shift = if (den != 0f) (a - c) / (2 * den) else 0f
        return sampleRate / (tau + shift.toDouble())
    }
}
