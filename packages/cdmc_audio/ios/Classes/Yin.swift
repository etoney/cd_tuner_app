import Foundation

/// Pitch tracking for guitar and bass (about 27 Hz to 1400 Hz, so a
/// 5-string bass's low B0 at 30.87 Hz is covered).
///
/// The microphone signal is first band-passed (25 Hz to 1.5 kHz) and
/// decimated by 4. That strips out hiss and room noise above the strings'
/// useful range, so quiet notes from a phone at arm's length still read
/// accurately. Then YIN finds the period. Same algorithm as Yin.kt on Android.
final class PitchTracker {
    private let decim = 4
    let rate: Double
    private var lp1: Biquad, lp2: Biquad, hp: Biquad
    private var phase = 0
    // ~340 ms window: long enough to keep a fading string readable.
    private var ring = [Float](repeating: 0, count: 4096)
    private var pos = 0
    private var filled = 0
    private var sinceLast = 0
    /// The pitch we're locked onto, so a fading note stays tracked.
    private var locked = -1.0
    private var misses = 0

    /// Forget the locked pitch so the next string is picked up at once.
    func resetLock() { locked = -1; misses = 0 }

    init(inputRate: Double) {
        rate = inputRate / Double(decim)
        lp1 = .lowPass(1500, inputRate)
        lp2 = .lowPass(1500, inputRate)
        hp = .highPass(25, inputRate)
    }

    /// Feeds raw microphone samples; calls [onReading] about ten times a second.
    func push(_ samples: UnsafeBufferPointer<Float>, onReading: (Double) -> Void) {
        for x in samples {
            let y = hp.process(lp2.process(lp1.process(x)))
            phase += 1
            if phase < decim { continue }
            phase = 0
            ring[pos] = y
            pos = (pos + 1) % ring.count
            if filled < ring.count { filled += 1 }
            sinceLast += 1
            if filled == ring.count && sinceLast >= Int(rate / 10) {
                sinceLast = 0
                let window = Array(ring[pos...] + ring[..<pos])
                let hz = Yin.track(window, sampleRate: rate, locked: locked)
                if hz > 0 { locked = hz; misses = 0 } else { misses += 1; if misses >= 5 { locked = -1 } }
                onReading(hz)
            }
        }
    }
}

struct Biquad {
    let b0, b1, b2, a1, a2: Double
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    mutating func process(_ x: Float) -> Float {
        let y = b0 * Double(x) + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = Double(x); y2 = y1; y1 = y
        return Float(y)
    }

    static let q = 0.7071

    static func lowPass(_ f: Double, _ sr: Double) -> Biquad {
        let w = 2 * Double.pi * f / sr, c = cos(w), a = sin(w) / (2 * q), a0 = 1 + a
        return Biquad(b0: (1 - c) / 2 / a0, b1: (1 - c) / a0, b2: (1 - c) / 2 / a0, a1: -2 * c / a0, a2: (1 - a) / a0)
    }

    static func highPass(_ f: Double, _ sr: Double) -> Biquad {
        let w = 2 * Double.pi * f / sr, c = cos(w), a = sin(w) / (2 * q), a0 = 1 + a
        return Biquad(b0: (1 + c) / 2 / a0, b1: -(1 + c) / a0, b2: (1 + c) / 2 / a0, a1: -2 * c / a0, a2: (1 - a) / a0)
    }
}

enum Yin {
    static let threshold: Float = 0.15
    static let relative: Float = 1.6
    static let strong: Float = 0.35      // clear pitch: accept anywhere
    static let weak: Float = 0.6         // fading note: accept only near the locked pitch
    static let minRms: Float = 0.00015   // essentially silence

    /// Returns the fundamental in Hz, or -1 when there's no usable pitch.
    /// [locked] is the last good reading (or -1): a fading note that is too
    /// weak to find from scratch is still followed if it stays near it.
    static func track(_ b: [Float], sampleRate: Double, locked: Double) -> Double {
        var sum: Float = 0
        for x in b { sum += x * x }
        if (sum / Float(b.count)).squareRoot() < minRms { return -1 }

        let minLag = Int(sampleRate / 1400)
        let maxLag = Int(sampleRate / 27)
        let w = b.count - maxLag - 2
        if w <= 0 { return -1 }
        var d = [Float](repeating: 1, count: maxLag + 2)
        var run: Double = 0
        b.withUnsafeBufferPointer { p in
            for t in 1...(maxLag + 1) {
                var s: Double = 0
                for i in 0..<w {
                    let x = p[i] - p[i + t]
                    s += Double(x * x)
                }
                run += s
                d[t] = run > 0 ? Float(s * Double(t) / run) : 1
            }
        }

        // 1. Search from scratch: first dip that is nearly as good as the best.
        var gmin = Float.greatestFiniteMagnitude
        for t in minLag..<maxLag where d[t] < gmin { gmin = d[t] }
        let limit = max(threshold, gmin * relative)
        var tau = minLag
        while tau < maxLag && d[tau] >= limit { tau += 1 }
        while tau + 1 < maxLag && d[tau + 1] < d[tau] { tau += 1 }
        let free = refine(d, tau, sampleRate)
        // A clear reading always wins, so a newly plucked string takes over
        // even while the previous one is still ringing.
        if d[tau] < strong { return free }

        // 2. Follow the locked pitch within about ±60 cents.
        guard locked > 0 else { return -1 }
        let p = sampleRate / locked
        let lo = max(2, Int(p / 1.035)), hi = min(maxLag - 1, Int(p * 1.035) + 1)
        var best = lo
        for t in lo...hi where d[t] < d[best] { best = t }
        return d[best] < weak ? refine(d, best, sampleRate) : -1
    }

    private static func refine(_ d: [Float], _ tau: Int, _ sampleRate: Double) -> Double {
        let a = d[tau - 1], c = d[tau + 1]
        let den = a + c - 2 * d[tau]
        let shift = den != 0 ? (a - c) / (2 * den) : 0
        return sampleRate / (Double(tau) + Double(shift))
    }
}
