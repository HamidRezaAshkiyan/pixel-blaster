import AVFoundation
import Foundation

enum SoundEffect: CaseIterable {
    case pistolShot
    case shotgunShot
    case smgShot
    case railgunShot
    case hit
    case enemyDeath
    case playerHurt
    case dash
    case pickup
    case upgrade
    case waveStart
    case uiMove
    case uiConfirm
}

final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayerIdx = 0
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44100.0
    var isMuted: Bool = false

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        for _ in 0..<12 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.35

        for sfx in SoundEffect.allCases {
            buffers[sfx] = generateBuffer(for: sfx, format: format)
        }

        try? engine.start()
        for player in players {
            player.play()
        }
    }

    func play(_ sfx: SoundEffect) {
        guard !isMuted, let buffer = buffers[sfx] else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        let player = players[nextPlayerIdx]
        nextPlayerIdx = (nextPlayerIdx + 1) % players.count
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private func generateBuffer(for sfx: SoundEffect, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Double
        switch sfx {
        case .pistolShot: duration = 0.09
        case .shotgunShot: duration = 0.18
        case .smgShot: duration = 0.06
        case .railgunShot: duration = 0.25
        case .hit: duration = 0.05
        case .enemyDeath: duration = 0.20
        case .playerHurt: duration = 0.22
        case .dash: duration = 0.14
        case .pickup: duration = 0.11
        case .upgrade: duration = 0.32
        case .waveStart: duration = 0.38
        case .uiMove: duration = 0.04
        case .uiConfirm: duration = 0.12
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var phase: Double = 0
        var lfsr: UInt32 = 0xACE1

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let env = Float(max(0, 1.0 - progress))

            // Simple pseudo-noise for retro crunch
            let bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1
            lfsr = (lfsr >> 1) | (bit << 15)
            let noise = (Float(lfsr & 0xFF) / 127.5) - 1.0

            let sample: Float
            switch sfx {
            case .pistolShot:
                let freq = 620.0 - 420.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.5 : -0.5
                sample = (sq * 0.7 + noise * 0.3) * env * 0.55

            case .shotgunShot:
                let freq = 180.0 - 110.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.6 : -0.6
                sample = (sq * 0.4 + noise * 0.85) * env * env * 0.85

            case .smgShot:
                let freq = 860.0 - 500.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.5 : -0.5
                sample = (sq * 0.75 + noise * 0.25) * env * 0.45

            case .railgunShot:
                let freq = 1400.0 - 1150.0 * pow(progress, 0.6)
                phase += (2.0 * .pi * freq) / sampleRate
                let saw = Float((phase.truncatingRemainder(dividingBy: 2.0 * .pi)) / .pi - 1.0)
                sample = (saw * 0.7 + noise * 0.4) * env * 0.75

            case .hit:
                let freq = 260.0 - 120.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                sample = (noise * 0.6 + Float(sin(phase)) * 0.4) * env * 0.45

            case .enemyDeath:
                let freq = 240.0 - 190.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.6 : -0.6
                sample = (sq * 0.5 + noise * 0.65) * env * 0.7

            case .playerHurt:
                let freq = 160.0 - 95.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.7 : -0.7
                sample = (sq * 0.8 + noise * 0.3) * env * 0.8

            case .dash:
                let freq = 280.0 + 380.0 * progress
                phase += (2.0 * .pi * freq) / sampleRate
                sample = (noise * 0.5 + Float(sin(phase)) * 0.3) * env * 0.45

            case .pickup:
                let freq = progress < 0.45 ? 740.0 : 1120.0
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.45 : -0.45
                sample = sq * env * 0.5

            case .upgrade:
                let step = Int(progress * 4.0)
                let notes = [523.25, 659.25, 783.99, 1046.50]
                let freq = notes[min(step, notes.count - 1)]
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.5 : -0.5
                sample = sq * env * 0.6

            case .waveStart:
                let step = Int(progress * 3.0)
                let notes = [330.0, 440.0, 659.25]
                let freq = notes[min(step, notes.count - 1)]
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.5 : -0.5
                sample = sq * env * 0.55

            case .uiMove:
                let freq = 520.0
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.4 : -0.4
                sample = sq * env * 0.35

            case .uiConfirm:
                let freq = progress < 0.5 ? 600.0 : 900.0
                phase += (2.0 * .pi * freq) / sampleRate
                let sq: Float = sin(phase) >= 0 ? 0.45 : -0.45
                sample = sq * env * 0.45
            }

            data[i] = max(-1.0, min(1.0, sample))
        }

        return buffer
    }
}
