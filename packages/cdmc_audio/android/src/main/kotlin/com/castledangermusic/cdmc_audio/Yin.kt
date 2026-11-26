package com.castledangermusic.cdmc_audio

import kotlin.math.sqrt

/**
 * YIN pitch detector, tuned for guitar and bass (about 27 Hz to 1400 Hz,
 * which covers a 5-string bass's low B0 at 30.87 Hz).
 * Same algorithm as Yin.swift on iOS.
 */
object Yin {
    private const val THRESHOLD = 0.12f
    private const val MIN_RMS = 0.008f

    /** Returns the fundamental in Hz, or -1 when the signal is too quiet or unpitched. */
    fun detect(b: FloatArray, sampleRate: Int): Double {
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
            var i = 0
            while (i < w) {
                val x = b[i] - b[i + t]
                s += x * x
                i += 2
            }
            run += s
            d[t] = if (run > 0) (s * t / run).toFloat() else 1f
        }
        var tau = -1
        for (t in minLag until maxLag) {
            if (d[t] < THRESHOLD) { tau = t; break }
        }
        if (tau < 0) return -1.0
        while (tau + 1 < maxLag && d[tau + 1] < d[tau]) tau++
        val a = d[tau - 1]
        val c = d[tau + 1]
        val den = a + c - 2 * d[tau]
        val shift = if (den != 0f) (a - c) / (2 * den) else 0f
        return sampleRate / (tau + shift.toDouble())
    }
}
