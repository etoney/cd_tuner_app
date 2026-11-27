package com.castledangermusic.cdmc_audio

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Clean reference tone: a fundamental with a few soft overtones, all kept
 * below 1.6 kHz so it never sounds buzzy. Phone speakers can't play the
 * fundamental of a low string, so low notes lean a little more on the
 * overtones a speaker can play; the ear still hears the right pitch.
 */
class RefTone(private val sr: Double) {
    private var w = DoubleArray(0)
    private var hz = -1.0
    private var phase = 0.0

    fun next(f: Double): Double {
        if (f <= 0) return 0.0
        if (f != hz) { hz = f; w = weights(f) }
        phase += f / sr
        if (phase >= 1) phase -= floor(phase)
        val th = 2 * PI * phase
        val c2 = 2 * cos(th)
        var prev = 0.0
        var cur = sin(th)
        var out = 0.0
        for (a in w) {
            out += a * cur
            val nx = c2 * cur - prev
            prev = cur
            cur = nx
        }
        return out
    }

    companion object {
        private const val MAX = 16

        /** How well a phone speaker plays [f], roughly. */
        private fun speaker(f: Double): Double {
            var c = when {
                f < 120 -> 0.3
                f < 250 -> 0.3 + 0.7 * (f - 120) / 130
                else -> 1.0
            }
            if (f > 800) c *= ((1600 - f) / 800).coerceAtLeast(0.0)
            return c
        }

        /** Harmonic amplitudes for a note at [f] Hz (RMS about 0.6). */
        fun weights(f: Double): DoubleArray {
            val list = ArrayList<Double>()
            for (k in 1..MAX) {
                val fk = k * f
                if (fk > 1600) break
                list.add(speaker(fk) / k.toDouble().pow(1.2))
            }
            if (list.isEmpty()) list.add(1.0)
            val w = list.toDoubleArray()
            var sum2 = 0.0
            var aud2 = 0.0
            for (k in w.indices) {
                sum2 += w[k] * w[k]
                if ((k + 1) * f >= 250) aud2 += w[k] * w[k]
            }
            var norm = 0.6 / sqrt(sum2 / 2)
            // Low notes: make up some of the level the speaker can't play.
            val audible = sqrt(aud2 / 2) * norm
            if (audible > 0 && audible < 0.45) norm *= min(1.6, 0.45 / audible)
            for (k in w.indices) w[k] *= norm
            return w
        }

        /** A clean plucked note for "Hear it": upper overtones fade first. */
        fun pluck(f: Double, sr: Int): FloatArray {
            val w = weights(f)
            val n = (2.2 * sr).toInt()
            val out = FloatArray(n)
            for (i in 0 until n) {
                val t = i.toDouble() / sr
                val attack = min(1.0, t / 0.008)
                var s = 0.0
                for (k in w.indices) {
                    s += w[k] * exp(-t * (1.4 + 0.25 * (k + 1))) * sin(2 * PI * (k + 1) * f * t)
                }
                out[i] = (0.28 * attack * s).toFloat()
            }
            return out
        }
    }
}
