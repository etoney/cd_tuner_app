import Foundation

/// Reference tone built from a stack of harmonics. Phone speakers can't play
/// the fundamental of a low string, but the ear hears the right pitch from its
/// overtones, so low notes lean on harmonics in the range a speaker can play.
final class RefTone {
    private static let maxHarmonics = 24
    private let sr: Double
    private var w = [Double](repeating: 0, count: RefTone.maxHarmonics)
    private var n = 0
    private var hz = -1.0
    private var phase = 0.0

    init(sampleRate: Double) { sr = sampleRate }

    private func setup(_ f: Double) {
        hz = f
        n = 0
        var sum2 = 0.0
        for k in 1...RefTone.maxHarmonics {
            let fk = Double(k) * f
            if fk > 4000 { break }
            var a = 1.0 / pow(Double(k), 0.8)
            if fk < 120 { a *= 0.3 } else if fk < 250 { a *= 0.7 }
            if fk > 2000 { a *= (4000 - fk) / 2000 }
            w[k - 1] = a
            n = k
            sum2 += a * a
        }
        let norm = sum2 > 0 ? 0.6 / (sum2 / 2).squareRoot() : 0
        for k in 0..<n { w[k] *= norm }
    }

    func next(_ f: Double) -> Double {
        if f <= 0 { return 0 }
        if f != hz { setup(f) }
        phase += f / sr
        if phase >= 1 { phase -= floor(phase) }
        let th = 2 * Double.pi * phase
        let c2 = 2 * cos(th)
        var prev = 0.0
        var cur = sin(th)
        var out = 0.0
        for k in 0..<n {
            out += w[k] * cur
            let nx = c2 * cur - prev
            prev = cur
            cur = nx
        }
        return out
    }
}
