import Foundation

/// YIN pitch detector, tuned for guitar and bass (about 27 Hz to 1400 Hz).
/// Same algorithm as Yin.kt on Android.
enum Yin {
    static let threshold: Float = 0.12
    static let minRms: Float = 0.003

    /// Returns the fundamental in Hz, or -1 when the signal is too quiet or unpitched.
    static func detect(_ b: [Float], sampleRate: Double) -> Double {
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
                var i = 0
                while i < w {
                    let x = p[i] - p[i + t]
                    s += Double(x * x)
                    i += 2
                }
                run += s
                d[t] = run > 0 ? Float(s * Double(t) / run) : 1
            }
        }
        var tau = -1
        for t in minLag..<maxLag where d[t] < threshold { tau = t; break }
        if tau < 0 { return -1 }
        while tau + 1 < maxLag && d[tau + 1] < d[tau] { tau += 1 }
        let a = d[tau - 1], c = d[tau + 1]
        let den = a + c - 2 * d[tau]
        let shift = den != 0 ? (a - c) / (2 * den) : 0
        return sampleRate / (Double(tau) + Double(shift))
    }
}
