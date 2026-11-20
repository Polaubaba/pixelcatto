// PomoCat.swift
// A Pomodoro timer for macOS with a pixel cat, synthesized meows and small effects.
//
// Setup (Xcode 15 or newer, macOS 13 or newer):
// 1. File > New > Project > macOS > App. Interface: SwiftUI. Language: Swift.
// 2. Delete the generated ContentView.swift and the generated *App.swift file.
// 3. Drag this file into the project, then press Run (Cmd+R).

import SwiftUI
import AVFoundation
import Combine

// MARK: - App entry point

@main
struct PomoCatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Pomodoro phases

enum PomoPhase {
    case focus, shortBreak, longBreak

    /// Change these to adjust the Pomodoro lengths.
    var seconds: Int {
        switch self {
        case .focus:      return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak:  return 15 * 60
        }
    }

    var title: String {
        switch self {
        case .focus:      return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak:  return "Long break"
        }
    }

    var accent: Color {
        switch self {
        case .focus:      return Color(hex: 0xE0533D)   // tomato
        case .shortBreak: return Color(hex: 0x2E9C7E)   // teal
        case .longBreak:  return Color(hex: 0x5A6FD6)   // periwinkle
        }
    }
}

// MARK: - Colors

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let catOutline = Color(hex: 0x1E1B1F)
    static let catNose = Color(hex: 0xF4A6B7)
}

// MARK: - Pixel cat

/// Sprite legend:
/// O outline, B body, S stripes and shade, W patch (chest and paws),
/// E eye, N nose, . empty
let catSprite: [String] = [
    ".OO........OO.",
    ".OBO......OBO.",
    ".OBBOOOOOOBBO.",
    ".OBBBSBBSBBBO.",
    ".OBBBBBBBBBBO.",
    ".OBBEBBBBEBBO.",
    ".OBBBBNNBBBBO.",
    "..OBBBBBBBBO..",
    ".OBBBBBBBBBBO.",
    ".OBBWWWWWWBBO.",
    ".OBBWWWWWWBBO.",
    ".OBBBBBBBBBBO.",
    ".OWWBBBBBBWWO.",
    "..OOOOOOOOOO..",
]

enum CatColor: String, CaseIterable, Identifiable {
    case ginger = "Ginger"
    case black = "Black"
    case white = "White"
    case tuxedo = "Tuxedo"

    var id: String { rawValue }

    var palette: CatPalette {
        switch self {
        case .ginger:
            return CatPalette(body: Color(hex: 0xF0A04B), shade: Color(hex: 0xC26A25),
                              patch: Color(hex: 0xFCEBD2), eye: Color(hex: 0x8FD16A))
        case .black:
            return CatPalette(body: Color(hex: 0x2F2F35), shade: Color(hex: 0x1B1B20),
                              patch: Color(hex: 0x44444C), eye: Color(hex: 0xF5D547))
        case .white:
            return CatPalette(body: Color(hex: 0xF5F5F7), shade: Color(hex: 0xC8C9D2),
                              patch: Color(hex: 0xFFFFFF), eye: Color(hex: 0x5BB8FF))
        case .tuxedo:
            return CatPalette(body: Color(hex: 0x2F2F35), shade: Color(hex: 0x1B1B20),
                              patch: Color(hex: 0xF5F5F7), eye: Color(hex: 0x8FD16A))
        }
    }
}

struct CatPalette {
    let body: Color
    let shade: Color
    let patch: Color
    let eye: Color

    func color(for symbol: Character, closedEyes: Bool) -> Color? {
        switch symbol {
        case "O": return .catOutline
        case "B": return body
        case "S": return shade
        case "W": return patch
        case "E": return closedEyes ? .catOutline : eye
        case "N": return .catNose
        default:  return nil
        }
    }
}

struct PixelCat: View {
    let color: CatColor
    let closedEyes: Bool
    var pixel: CGFloat = 9

    var body: some View {
        let palette = color.palette
        Canvas { context, _ in
            for (y, row) in catSprite.enumerated() {
                for (x, symbol) in row.enumerated() {
                    guard let fill = palette.color(for: symbol, closedEyes: closedEyes) else { continue }
                    let rect = CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel,
                                      width: pixel, height: pixel)
                    context.fill(Path(rect), with: .color(fill))
                }
            }
        }
        .frame(width: pixel * 14, height: pixel * 14)
    }
}

// MARK: - Meow sounds (synthesized, no audio files needed)

struct MeowTone: Identifiable {
    let id: String
    let name: String
    let baseFrequency: Double                       // Hz
    let duration: Double                            // seconds
    let contour: [(time: Double, pitch: Double)]    // pitch curve over the meow
    let harmonics: Int                              // more harmonics = buzzier
    let brightness: Double                          // higher = softer
    let wobble: Double                              // mouth movement speed

    func pitchMultiplier(at x: Double) -> Double {
        guard let first = contour.first else { return 1 }
        if x <= first.time { return first.pitch }
        for (a, b) in zip(contour, contour.dropFirst()) where x <= b.time {
            return a.pitch + (b.pitch - a.pitch) * (x - a.time) / (b.time - a.time)
        }
        return contour.last?.pitch ?? 1
    }

    static let all: [MeowTone] = [
        MeowTone(id: "classic", name: "Classic", baseFrequency: 620, duration: 0.75,
                 contour: [(0.0, 0.85), (0.25, 1.15), (0.7, 1.05), (1.0, 0.8)],
                 harmonics: 10, brightness: 1.2, wobble: 4),
        MeowTone(id: "kitten", name: "Kitten", baseFrequency: 1000, duration: 0.4,
                 contour: [(0.0, 1.0), (0.3, 1.35), (1.0, 1.1)],
                 harmonics: 6, brightness: 1.5, wobble: 8),
        MeowTone(id: "long", name: "Long", baseFrequency: 430, duration: 1.3,
                 contour: [(0.0, 1.0), (0.3, 1.2), (0.7, 1.1), (1.0, 0.75)],
                 harmonics: 12, brightness: 1.1, wobble: 3),
        MeowTone(id: "grumpy", name: "Grumpy", baseFrequency: 280, duration: 0.9,
                 contour: [(0.0, 1.15), (0.4, 0.95), (1.0, 0.7)],
                 harmonics: 14, brightness: 0.9, wobble: 6),
        MeowTone(id: "question", name: "Question", baseFrequency: 480, duration: 0.85,
                 contour: [(0.0, 0.8), (0.6, 1.1), (1.0, 1.6)],
                 harmonics: 10, brightness: 1.2, wobble: 5),
    ]
}

final class MeowPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, fromBus: 0, toBus: 0, format: format)
        do {
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    func play(_ tone: MeowTone) {
        guard let buffer = makeBuffer(for: tone) else { return }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private func makeBuffer(for tone: MeowTone) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(tone.duration * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        var phase = 0.0
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            let progress = t / tone.duration

            // Pitch follows the contour, with a little vibrato.
            let pitch = tone.baseFrequency
                * tone.pitchMultiplier(at: progress)
                * (1 + 0.015 * sin(2 * .pi * 5.5 * t))
            phase += 2 * .pi * pitch / rate

            // Voice-like harmonic stack.
            var voice = 0.0
            for h in 1...tone.harmonics {
                voice += sin(Double(h) * phase) / pow(Double(h), tone.brightness)
            }

            let attack = min(1, t / 0.07)
            let release = min(1, (tone.duration - t) / 0.15)
            let mouth = 0.8 + 0.2 * sin(2 * .pi * tone.wobble * t)
            let breath = Double.random(in: -0.03...0.03)

            samples[i] = Float((voice + breath) * attack * release * mouth * 0.3)
        }
        return buffer
    }
}

// MARK: - App state

@MainActor
final class PomoModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var phase: PomoPhase = .focus
    @Published var remaining: Int = PomoPhase.focus.seconds
    @Published var isRunning = false
    @Published var completedFocus = 0
    @Published var catColor: CatColor = .ginger
    @Published var toneID = "classic"
    @Published var soundOn = true
    @Published var confettiStart: Date?

    private var timer: Timer?
    private let meow = MeowPlayer()

    var tone: MeowTone {
        MeowTone.all.first(where: { $0.id == toneID }) ?? MeowTone.all[0]
    }

    var progress: Double {
        1 - Double(remaining) / Double(phase.seconds)
    }

    var timeText: String {
        String(format: "%02ld:%02ld", remaining / 60, remaining % 60)
    }

    func toggle() {
        if isRunning { pause() } else { start() }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
    }

    @objc private func timerFired() {
        tick()
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func reset() {
        pause()
        remaining = phase.seconds
    }

    func skip() {
        pause()
        move(to: phase == .focus ? .shortBreak : .focus)
    }

    func meowNow() {
        if soundOn { meow.play(tone) }
    }

    private func tick() {
        guard remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 { finish() }
    }

    private func finish() {
        pause()
        let finished = phase
        if finished == .focus { completedFocus += 1 }
        let next: PomoPhase = finished == .focus
            ? (completedFocus % 4 == 0 ? .longBreak : .shortBreak)
            : .focus
        move(to: next)
        meowNow()
        confettiStart = Date()
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            confettiStart = nil
        }
    }

    private func move(to next: PomoPhase) {
        phase = next
        remaining = next.seconds
    }
}

// MARK: - Effects

struct ConfettiPiece {
    let x = CGFloat.random(in: 0...1)
    let speed = CGFloat.random(in: 120...240)
    let spin = Double.random(in: -6...6)
    let wobble = Double.random(in: 1...3)
    let delay = Double.random(in: 0...0.6)
    let color = [Color.pink, .yellow, .mint, .orange, .blue, .purple].randomElement() ?? .pink
}

struct ConfettiView: View {
    let start: Date
    private let pieces = (0..<90).map { _ in ConfettiPiece() }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                for piece in pieces {
                    let x = piece.x * size.width + CGFloat(sin(t * piece.wobble)) * 18
                    let y = -20 + piece.speed * CGFloat(max(0, t - piece.delay))
                    guard y < size.height + 20 else { continue }
                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(t * piece.spin))
                    ctx.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)),
                             with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct Heart: Identifiable {
    let id = UUID()
    let symbol: String
    let x: CGFloat
}

struct RisingEmoji: View {
    let heart: Heart
    @State private var lifted = false

    var body: some View {
        Text(heart.symbol)
            .font(.system(size: 22))
            .offset(x: heart.x, y: lifted ? -130 : -20)
            .opacity(lifted ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3)) { lifted = true }
            }
    }
}

// MARK: - Main view

struct ContentView: View {
    @StateObject private var model = PomoModel()
    @State private var blinking = false
    @State private var bob = false
    @State private var squish = false
    @State private var hearts: [Heart] = []

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Text(model.phase.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.phase.accent)

                Text(model.timeText)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                cat
                    .frame(width: 230, height: 190)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(model.phase.accent.opacity(0.12))
                    )
                    .animation(.easeInOut(duration: 0.6), value: model.phase)

                ProgressView(value: model.progress)
                    .tint(model.phase.accent)

                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < cyclesDone ? model.phase.accent : Color.gray.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                }

                controls

                Picker("Cat", selection: $model.catColor) {
                    ForEach(CatColor.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                soundRow
            }
            .padding(24)

            if let start = model.confettiStart {
                ConfettiView(start: start)
                    .id(start)
            }
        }
        .frame(width: 340, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await blinkLoop() }
        .onAppear { bob = true }
    }

    // The cat, its reactions, and the sleeping "zzz" during breaks.
    private var cat: some View {
        ZStack {
            PixelCat(color: model.catColor,
                     closedEyes: blinking || model.phase != .focus)
                .scaleEffect(squish ? 0.9 : 1)
                .offset(y: bob ? -6 : 0)
                .onTapGesture { pet() }

            if model.phase != .focus {
                Text("zzz")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(model.phase.accent)
                    .offset(x: 58, y: -52)
                    .allowsHitTesting(false)
            }

            ForEach(hearts) { RisingEmoji(heart: $0) }
        }
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                model.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset (⌘R)")
            .keyboardShortcut("r", modifiers: .command)

            Button {
                model.toggle()
            } label: {
                Label(model.isRunning ? "Pause" : "Start",
                      systemImage: model.isRunning ? "pause.fill" : "play.fill")
                    .frame(width: 110)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.phase.accent)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])

            Button {
                model.skip()
            } label: {
                Image(systemName: "forward.fill")
            }
            .help("Skip to next phase (⌘S)")
            .keyboardShortcut("s", modifiers: .command)
        }
    }

    private var soundRow: some View {
        HStack(spacing: 10) {
            Picker("Meow", selection: $model.toneID) {
                ForEach(MeowTone.all) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .frame(width: 130)

            Button {
                model.meowNow()
            } label: {
                Label("Meow", systemImage: "pawprint.fill")
            }
            .disabled(!model.soundOn)

            Toggle(isOn: $model.soundOn) {
                Image(systemName: model.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .toggleStyle(.button)
            .help("Sound on or off")
        }
    }

    /// Cycle dots: 1 to 4 filled, then restart at 1 after each long break.
    private var cyclesDone: Int {
        model.completedFocus == 0 ? 0 : (model.completedFocus - 1) % 4 + 1
    }

    private func pet() {
        model.meowNow()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.35)) { squish = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring()) { squish = false }
        }

        let heart = Heart(symbol: ["❤️", "🐾", "✨", "💛"].randomElement() ?? "❤️",
                          x: CGFloat.random(in: -50...50))
        hearts.append(heart)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hearts.removeAll { $0.id == heart.id }
        }
    }

    /// Blinks every few seconds.
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 2_000_000_000...4_500_000_000))
            blinking = true
            try? await Task.sleep(nanoseconds: 140_000_000)
            blinking = false
        }
    }
}

