import Foundation

/// Clean reference tone: a fundamental with a few soft overtones, all kept
/// below 1.6 kHz so it never sounds buzzy. Phone speakers can't play the
/// fundamental of a low string, so low notes lean a little more on the
/// overtones a speaker can play; the ear still hears the right pitch.
final class RefTone {
    private let sr: Double
    private var w: [Double] = []
    private var hz = -1.0
    private var phase = 0.0

    init(sampleRate: Double) { sr = sampleRate }

    func next(_ f: Double) -> Double {
        if f <= 0 { return 0 }
        if f != hz { hz = f; w = RefTone.weights(f) }
        phase += f / sr
        if phase >= 1 { phase -= floor(phase) }
        let th = 2 * Double.pi * phase
        let c2 = 2 * cos(th)
        var prev = 0.0
        var cur = sin(th)
        var out = 0.0
        for a in w {
            out += a * cur
            let nx = c2 * cur - prev
            prev = cur
            cur = nx
        }
        return out
    }

    /// How well a phone speaker plays [f], roughly.
    private static func speaker(_ f: Double) -> Double {
        var c: Double
        if f < 120 { c = 0.3 } else if f < 250 { c = 0.3 + 0.7 * (f - 120) / 130 } else { c = 1 }
        if f > 800 { c *= max(0, (1600 - f) / 800) }
        return c
    }

    /// Harmonic amplitudes for a note at [f] Hz (RMS about 0.6).
    static func weights(_ f: Double) -> [Double] {
        var w: [Double] = []
        for k in 1...16 {
            let fk = Double(k) * f
            if fk > 1600 { break }
            w.append(speaker(fk) / pow(Double(k), 1.2))
        }
        if w.isEmpty { w = [1] }
        var sum2 = 0.0, aud2 = 0.0
        for k in 0..<w.count {
            sum2 += w[k] * w[k]
            if Double(k + 1) * f >= 250 { aud2 += w[k] * w[k] }
        }
        var norm = 0.6 / (sum2 / 2).squareRoot()
        // Low notes: make up some of the level the speaker can't play.
        let audible = (aud2 / 2).squareRoot() * norm
        if audible > 0 && audible < 0.45 { norm *= min(1.6, 0.45 / audible) }
        return w.map { $0 * norm }
    }

    /// A clean plucked note for "Hear it": upper overtones fade first.
    static func pluck(_ f: Double, sampleRate sr: Double) -> [Float] {
        let w = weights(f)
        let n = Int(2.2 * sr)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sr
            let attack = min(1, t / 0.008)
            var s = 0.0
            for k in 0..<w.count {
                let kk = Double(k + 1)
                s += w[k] * exp(-t * (1.4 + 0.25 * kk)) * sin(2 * Double.pi * kk * f * t)
            }
            out[i] = Float(0.28 * attack * s)
        }
        return out
    }
}
