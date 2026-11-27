package com.castledangermusic.cdmc_audio

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Reference tone built from a stack of harmonics. Phone speakers can't play
 * the fundamental of a low string, but the ear hears the right pitch from its
 * overtones, so low notes lean on harmonics in the range a speaker can play.
 */
class RefTone(private val sr: Double) {
    private val w = DoubleArray(MAX)
    private var n = 0
    private var hz = -1.0
    private var phase = 0.0

    private fun setup(f: Double) {
        hz = f
        n = 0
        var sum2 = 0.0
        for (k in 1..MAX) {
            val fk = k * f
            if (fk > 4000) break
            var a = 1.0 / k.toDouble().pow(0.8)
            if (fk < 120) a *= 0.3 else if (fk < 250) a *= 0.7
            if (fk > 2000) a *= (4000 - fk) / 2000
            w[k - 1] = a
            n = k
            sum2 += a * a
        }
        val norm = if (sum2 > 0) 0.6 / sqrt(sum2 / 2) else 0.0
        for (k in 0 until n) w[k] *= norm
    }

    fun next(f: Double): Double {
        if (f <= 0) return 0.0
        if (f != hz) setup(f)
        phase += f / sr
        if (phase >= 1) phase -= floor(phase)
        val th = 2 * PI * phase
        val c2 = 2 * cos(th)
        var prev = 0.0
        var cur = sin(th)
        var out = 0.0
        for (k in 0 until n) {
            out += w[k] * cur
            val nx = c2 * cur - prev
            prev = cur
            cur = nx
        }
        return out
    }

    companion object { private const val MAX = 24 }
}
