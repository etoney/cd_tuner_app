import Foundation

/// The eight click presets, synthesised once into sample buffers.
/// Keep in step with Sounds.kt on Android so both platforms sound the same.
enum Sounds {
    enum Wave { case sine, triangle, square }

    struct Spec {
        let tones: [(Double, Wave)]
        let decay: Double
        var noise: Double = 0
        var highPass: Double = 1000
        var gain: Double = 1
        /// Pitch ratio for accented beats (1.5 = a fifth up; 0.75 = a bigger, deeper bell).
        var accentRatio: Double = 1.5
    }

    static let names = ["Church Bell", "Anvil", "Woodblock", "Rimshot", "Iron Bell", "Bone", "Hi-Hat", "Cowbell", "Beep"]

    static let specs: [Spec] = [
        // Church bell: hum, prime, tierce, quint and nominal partials with a long ring.
        Spec(tones: [(784, .sine), (392, .sine), (196, .sine), (470, .sine), (588, .sine), (1176, .sine), (1568, .sine)],
             decay: 1.4, noise: 0.08, highPass: 3000, accentRatio: 0.75),
        Spec(tones: [(1250, .triangle), (1980, .sine), (3100, .sine)], decay: 0.28),
        Spec(tones: [(820, .sine)], decay: 0.07, noise: 0.15, highPass: 1500),
        Spec(tones: [(420, .triangle)], decay: 0.05, noise: 0.6, highPass: 2000),
        Spec(tones: [(660, .sine), (1660, .sine), (2700, .sine)], decay: 0.7),
        Spec(tones: [(310, .sine)], decay: 0.06, noise: 0.4, highPass: 800),
        Spec(tones: [], decay: 0.05, noise: 1, highPass: 7000),
        Spec(tones: [(545, .square), (815, .square)], decay: 0.2, gain: 0.35),
        Spec(tones: [(1000, .sine)], decay: 0.09),
    ]

    /// Gain for each kind: 0 = subdivision, 1 = soft, 2 = click, 3 = accent.
    static let kindLevel: [Double] = [0.15, 0.25, 0.6, 1.0]

    static func wave(_ w: Wave, _ phase: Double) -> Double {
        let p = phase - floor(phase)
        switch w {
        case .sine: return sin(2 * .pi * p)
        case .triangle: return 1 - 4 * abs(p - 0.5)
        case .square: return p < 0.5 ? 1 : -1
        }
    }

    /// buffers[sound][kind]
    static func buffers(sampleRate sr: Double) -> [[[Float]]] {
        specs.map { spec in (0..<4).map { k in render(spec, kindLevel[k], k == 3, sr) } }
    }

    static func render(_ spec: Spec, _ level: Double, _ accent: Bool, _ sr: Double) -> [Float] {
        let n = Int((spec.decay + 0.02) * sr)
        var out = [Float](repeating: 0, count: n)
        let k = log(0.0001) / spec.decay
        let dt = 1 / sr
        let rc = 1 / (2 * .pi * spec.highPass)
        let a = rc / (rc + dt)
        var hpY = 0.0, prevX = 0.0
        var rng = SystemRandomNumberGenerator()
        let pitch = accent ? spec.accentRatio : 1.0
        for i in 0..<n {
            let t = Double(i) * dt
            let env = exp(k * t) * min(1, t / 0.0015)
            var s = 0.0
            for (idx, tone) in spec.tones.enumerated() {
                s += wave(tone.1, tone.0 * pitch * t) / Double(idx + 1)
            }
            if spec.noise > 0 {
                let x = Double.random(in: -1...1, using: &rng)
                hpY = a * (hpY + x - prevX)
                prevX = x
                s += hpY * spec.noise
            }
            out[i] = Float(s * env * level * 0.5 * spec.gain)
        }
        return out
    }
}
