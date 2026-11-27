import AVFoundation
import Foundation

/// One output stream mixes the metronome clicks, the reference tone and
/// plucked notes. Clicks are placed at exact sample positions inside the
/// render callback, so tempo is rock steady and does not depend on the UI.
/// With the "audio" background mode the stream keeps running on the lock screen.
@available(iOS 13.0, *)
final class AudioEngine {
    static let shared = AudioEngine()

    var onBeat: ((Int) -> Void)?
    var onPitch: ((Double) -> Void)?

    // MARK: render state (read on the audio thread)
    private final class Voice { let buf: [Float]; var pos = 0; init(_ b: [Float]) { buf = b } }
    private var lock = os_unfair_lock()
    private var pending: [Voice] = []
    private var voices: [Voice] = []

    private var bpm = 120.0
    private var beats: [Int] = [3, 2, 2, 2]
    private var subdivision = 1
    private var sound = 0
    private(set) var metronomeOn = false
    private var restart = false

    private var toneHz = 0.0
    private var toneOn = false
    private var tonePhase = 0.0
    private var toneGain = 0.0

    private var clock: Int64 = 0
    private var nextTick = 0.0
    private var step: Int64 = 0
    private var idleFrames = 0

    private var sampleRate = 48000.0
    private var bufs: [[[Float]]] = []

    private let out = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var outRunning = false
    private var idleTimer: Timer?
    private var tunerOn = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self = self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            if self.metronomeOn || self.toneOn { self.outRunning = false; self.ensureOutput() }
            if self.tunerOn { self.tunerOn = false; _ = self.startTuner() }
        }
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: out, queue: .main
        ) { [weak self] _ in
            guard let self = self, self.outRunning else { return }
            self.outRunning = false
            self.ensureOutput()
        }
    }

    // MARK: session

    private func configureSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            if tunerOn {
                try s.setCategory(.playAndRecord, mode: .measurement,
                                  options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
            } else {
                try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try s.setActive(true)
        } catch {
            NSLog("cdmc_audio session error: \(error)")
        }
    }

    // MARK: output

    private func ensureOutput() {
        if outRunning { return }
        configureSession()
        if source == nil {
            sampleRate = out.outputNode.outputFormat(forBus: 0).sampleRate
            if sampleRate <= 0 { sampleRate = 48000 }
            bufs = Sounds.buffers(sampleRate: sampleRate)
            let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let node = AVAudioSourceNode(format: fmt) { [unowned self] _, _, frameCount, abl in
                self.render(frameCount: Int(frameCount), abl: abl)
                return noErr
            }
            out.attach(node)
            out.connect(node, to: out.mainMixerNode, format: fmt)
            source = node
        }
        do {
            out.prepare()
            try out.start()
            outRunning = true
        } catch {
            NSLog("cdmc_audio output start failed: \(error)")
        }
        if idleTimer == nil {
            idleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.checkIdle() }
        }
    }

    private func checkIdle() {
        guard outRunning else { return }
        if idleFrames > Int(sampleRate * 2) && !metronomeOn && !toneOn {
            out.pause()
            outRunning = false
            idleTimer?.invalidate()
            idleTimer = nil
        }
    }

    private func latency() -> Double {
        let s = AVAudioSession.sharedInstance()
        return s.outputLatency + s.ioBufferDuration
    }

    private func render(frameCount: Int, abl: UnsafeMutablePointer<AudioBufferList>) {
        let list = UnsafeMutableAudioBufferListPointer(abl)
        guard let data = list[0].mData?.assumingMemoryBound(to: Float.self) else { return }

        os_unfair_lock_lock(&lock)
        if !pending.isEmpty { voices.append(contentsOf: pending); pending.removeAll(keepingCapacity: true) }
        let on = metronomeOn, sub = subdivision, pattern = beats, snd = sound
        let stepLen = sampleRate * 60 / bpm / Double(sub)
        if restart { restart = false; step = 0; nextTick = Double(clock) + sampleRate / 20 }
        let tHz = toneHz, tTarget = toneOn ? 0.18 : 0.0
        os_unfair_lock_unlock(&lock)

        var beatTimes: [(Int, Int)] = []
        for i in 0..<frameCount {
            if on && Double(clock) + Double(i) >= nextTick && !pattern.isEmpty {
                let beatIdx = Int((step / Int64(sub)) % Int64(pattern.count))
                let level = pattern[beatIdx]
                let isBeat = step % Int64(sub) == 0
                if level > 0 && snd < bufs.count {
                    voices.append(Voice(bufs[snd][isBeat ? level : 0]))
                }
                if isBeat { beatTimes.append((beatIdx, i)) }
                step += 1
                nextTick += stepLen
            }
            var s: Float = 0
            var j = 0
            while j < voices.count {
                let v = voices[j]
                if v.pos >= v.buf.count { voices.remove(at: j); continue }
                s += v.buf[v.pos]; v.pos += 1; j += 1
            }
            toneGain += (tTarget - toneGain) * 0.002
            if toneGain > 0.0005 {
                tonePhase += tHz / sampleRate
                if tonePhase >= 1 { tonePhase -= floor(tonePhase) }
                s += Float(toneGain * (1 - 4 * abs(tonePhase - 0.5)))
            }
            data[i] = max(-1, min(1, s))
        }
        for b in 1..<list.count { if let d = list[b].mData { memcpy(d, data, frameCount * 4) } }
        clock += Int64(frameCount)
        idleFrames = (voices.isEmpty && toneGain < 0.0005 && !on) ? idleFrames + frameCount : 0

        if !beatTimes.isEmpty {
            let lat = latency(), sr = sampleRate
            for (idx, offset) in beatTimes {
                DispatchQueue.main.asyncAfter(deadline: .now() + lat + Double(offset) / sr) { [weak self] in
                    guard let self = self, self.metronomeOn else { return }
                    self.onBeat?(idx)
                }
            }
        }
    }

    private func enqueue(_ v: Voice) {
        os_unfair_lock_lock(&lock); pending.append(v); os_unfair_lock_unlock(&lock)
    }

    // MARK: public API (main thread)

    func setMetronome(bpm: Double, beats: [Int], subdivision: Int, sound: Int, playing: Bool) {
        os_unfair_lock_lock(&lock)
        self.bpm = min(400, max(20, bpm))
        self.beats = beats.isEmpty ? [3] : beats
        self.subdivision = min(8, max(1, subdivision))
        self.sound = min(Sounds.names.count - 1, max(0, sound))
        let wasOn = metronomeOn
        if playing && !wasOn { restart = true }
        metronomeOn = playing
        os_unfair_lock_unlock(&lock)
        if playing { ensureOutput() } else if wasOn { onBeat?(-1) }
    }

    func previewSound(_ s: Int) {
        ensureOutput()
        guard !bufs.isEmpty else { return }
        enqueue(Voice(bufs[min(bufs.count - 1, max(0, s))][3]))
    }

    func pluck(_ hz: Double) {
        ensureOutput()
        enqueue(Voice(Sounds.pluck(hz: hz, sampleRate: sampleRate)))
    }

    func startTone(_ hz: Double) {
        os_unfair_lock_lock(&lock); toneHz = hz; toneOn = true; os_unfair_lock_unlock(&lock)
        ensureOutput()
    }

    func stopTone() {
        os_unfair_lock_lock(&lock); toneOn = false; os_unfair_lock_unlock(&lock)
    }

    // MARK: tuner

    private let rec = AVAudioEngine()
    private let detectQueue = DispatchQueue(label: "cdmc.pitch")
    private var tracker: PitchTracker?

    func requestMic(_ done: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            DispatchQueue.main.async { done(ok) }
        }
    }

    @discardableResult
    func startTuner() -> Bool {
        if tunerOn { return true }
        tunerOn = true
        configureSession()
        if outRunning { outRunning = false; ensureOutput() }
        let input = rec.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { tunerOn = false; return false }
        let tracker = PitchTracker(inputRate: fmt.sampleRate)
        self.tracker = tracker
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: fmt) { [weak self] buffer, _ in
            guard let self = self, let ch = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: ch, count: Int(buffer.frameLength)))
            self.detectQueue.async {
                samples.withUnsafeBufferPointer { p in
                    tracker.push(p) { hz in
                        DispatchQueue.main.async { self.onPitch?(hz) }
                    }
                }
            }
        }
        do {
            rec.prepare()
            try rec.start()
            return true
        } catch {
            NSLog("cdmc_audio input start failed: \(error)")
            input.removeTap(onBus: 0)
            tunerOn = false
            return false
        }
    }

    func resetPitchLock() {
        detectQueue.async { [weak self] in self?.tracker?.resetLock() }
    }

    func stopTuner() {
        guard tunerOn else { return }
        rec.inputNode.removeTap(onBus: 0)
        rec.stop()
        tunerOn = false
        configureSession()
        if outRunning { outRunning = false; ensureOutput() }
    }
}
