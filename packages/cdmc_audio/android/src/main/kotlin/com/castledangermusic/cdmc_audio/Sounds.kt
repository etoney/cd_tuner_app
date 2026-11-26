package com.castledangermusic.cdmc_audio

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * The eight click presets, synthesised once into sample buffers.
 * Keep in step with Sounds.swift on iOS so both platforms sound the same.
 */
object Sounds {
    enum class Wave { SINE, TRIANGLE, SQUARE }

    class Spec(
        val tones: List<Pair<Double, Wave>>,
        val decay: Double,
        val noise: Double = 0.0,
        val highPass: Double = 1000.0,
        val gain: Double = 1.0,
    )

    val names = listOf("Anvil", "Woodblock", "Rimshot", "Iron Bell", "Bone", "Hi-Hat", "Cowbell", "Beep")

    private val specs = listOf(
        Spec(listOf(1250.0 to Wave.TRIANGLE, 1980.0 to Wave.SINE, 3100.0 to Wave.SINE), 0.28),
        Spec(listOf(820.0 to Wave.SINE), 0.07, noise = 0.15, highPass = 1500.0),
        Spec(listOf(420.0 to Wave.TRIANGLE), 0.05, noise = 0.6, highPass = 2000.0),
        Spec(listOf(660.0 to Wave.SINE, 1660.0 to Wave.SINE, 2700.0 to Wave.SINE), 0.7),
        Spec(listOf(310.0 to Wave.SINE), 0.06, noise = 0.4, highPass = 800.0),
        Spec(emptyList(), 0.05, noise = 1.0, highPass = 7000.0),
        Spec(listOf(545.0 to Wave.SQUARE, 815.0 to Wave.SQUARE), 0.2, gain = 0.35),
        Spec(listOf(1000.0 to Wave.SINE), 0.09),
    )

    /** Gain for each kind: 0 = subdivision, 1 = soft, 2 = click, 3 = accent. */
    private val kindLevel = doubleArrayOf(0.15, 0.25, 0.6, 1.0)

    private var cacheRate = 0
    private var cache: Array<Array<FloatArray>> = emptyArray()

    /** buffers[sound][kind] at [sampleRate]. */
    @Synchronized
    fun buffers(sampleRate: Int): Array<Array<FloatArray>> {
        if (cacheRate != sampleRate) {
            cache = Array(specs.size) { s ->
                Array(4) { k -> render(specs[s], kindLevel[k], k == 3, sampleRate) }
            }
            cacheRate = sampleRate
        }
        return cache
    }

    private fun wave(w: Wave, phase: Double): Double {
        val p = phase - floor(phase)
        return when (w) {
            Wave.SINE -> sin(2 * PI * p)
            Wave.TRIANGLE -> 1 - 4 * abs(p - 0.5)
            Wave.SQUARE -> if (p < 0.5) 1.0 else -1.0
        }
    }

    private fun render(spec: Spec, level: Double, accent: Boolean, sr: Int): FloatArray {
        val n = ((spec.decay + 0.02) * sr).toInt()
        val out = FloatArray(n)
        val k = ln(0.0001) / spec.decay
        val dt = 1.0 / sr
        val rc = 1.0 / (2 * PI * spec.highPass)
        val a = rc / (rc + dt)
        var hpY = 0.0
        var prevX = 0.0
        val rnd = Random(7)
        val pitch = if (accent) 1.5 else 1.0
        for (i in 0 until n) {
            val t = i * dt
            val env = exp(k * t) * min(1.0, t / 0.0015)
            var s = 0.0
            spec.tones.forEachIndexed { idx, (f, w) -> s += wave(w, f * pitch * t) / (idx + 1) }
            if (spec.noise > 0) {
                val x = rnd.nextDouble() * 2 - 1
                hpY = a * (hpY + x - prevX)
                prevX = x
                s += hpY * spec.noise
            }
            out[i] = (s * env * level * 0.5 * spec.gain).toFloat()
        }
        return out
    }

    /** A plucked-string style note for "Hear it". */
    fun pluck(hz: Double, sr: Int): FloatArray {
        val n = (1.9 * sr).toInt()
        val out = FloatArray(n)
        val k = ln(0.0001) / 1.8
        for (i in 0 until n) {
            val t = i.toDouble() / sr
            val env = exp(k * t) * min(1.0, t / 0.01)
            out[i] = (0.3 * env * (wave(Wave.TRIANGLE, hz * t) + 0.3 * wave(Wave.SINE, 2 * hz * t))).toFloat()
        }
        return out
    }
}
