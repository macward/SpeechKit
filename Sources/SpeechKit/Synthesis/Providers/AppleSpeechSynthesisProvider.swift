#if canImport(AVFoundation)
import AVFoundation
import Foundation

// MARK: - Configuration

/// Configuration options for AppleSpeechSynthesisProvider.
public struct AppleSpeechSynthesisConfiguration: Sendable {
    /// Speech rate (0.0 to 1.0, default is AVSpeechUtteranceDefaultSpeechRate)
    public let rate: Float

    /// Speech pitch multiplier (0.5 to 2.0, default is 1.0)
    public let pitchMultiplier: Float

    /// Speech volume (0.0 to 1.0, default is 1.0)
    public let volume: Float

    /// Pre-utterance delay in seconds
    public let preUtteranceDelay: TimeInterval

    /// Post-utterance delay in seconds
    public let postUtteranceDelay: TimeInterval

    /// Creates a new configuration with the specified options.
    /// - Parameters:
    ///   - rate: Speech rate (default: system default)
    ///   - pitchMultiplier: Pitch multiplier (default: 1.0)
    ///   - volume: Volume level (default: 1.0)
    ///   - preUtteranceDelay: Delay before speaking (default: 0.0)
    ///   - postUtteranceDelay: Delay after speaking (default: 0.0)
    public init(
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitchMultiplier: Float = 1.0,
        volume: Float = 1.0,
        preUtteranceDelay: TimeInterval = 0.0,
        postUtteranceDelay: TimeInterval = 0.0
    ) {
        self.rate = rate
        self.pitchMultiplier = pitchMultiplier
        self.volume = volume
        self.preUtteranceDelay = preUtteranceDelay
        self.postUtteranceDelay = postUtteranceDelay
    }

    /// Default configuration using system defaults.
    public static let `default` = AppleSpeechSynthesisConfiguration()
}

// MARK: - AppleSpeechSynthesisProvider

/// Speech synthesis provider using Apple's AVSpeechSynthesizer.
///
/// This provider uses the built-in AVSpeechSynthesizer available on all Apple platforms.
/// It works offline and supports pause/resume functionality.
///
/// ## Thread Safety
///
/// This provider is `@MainActor` isolated. All public methods must be called from the main actor.
/// Delegate callbacks from AVSpeechSynthesizer are automatically bridged to the main actor.
///
/// ## Example Usage
///
/// ```swift
/// let provider = AppleSpeechSynthesisProvider()
///
/// // Subscribe to events
/// Task {
///     for await event in provider.events {
///         switch event {
///         case .started:
///             print("Speaking...")
///         case .completed:
///             print("Done!")
///         default:
///             break
///         }
///     }
/// }
///
/// // Speak text
/// try await provider.speak(text: "Hello, world!")
/// ```
@Observable
@MainActor
public final class AppleSpeechSynthesisProvider: NSObject, SpeechSynthesisProvider {
    // MARK: - Type Properties

    public static let identifier: String = "com.apple.avspeechsynthesizer"

    public static var isAvailable: Bool {
        // AVSpeechSynthesizer is available on all Apple platforms
        true
    }

    // MARK: - Instance Properties

    public private(set) var isPlaying: Bool = false
    public private(set) var isPaused: Bool = false

    public var capabilities: Set<SpeechSynthesisCapability> {
        [.pause, .resume, .offline]
    }

    /// Stream continuation for emitting events
    private var eventsContinuation: AsyncStream<SpeechSynthesisEvent>.Continuation?

    /// The events stream
    public var events: AsyncStream<SpeechSynthesisEvent> {
        AsyncStream { [weak self] continuation in
            self?.eventsContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.eventsContinuation = nil
                }
            }
        }
    }

    // MARK: - Private Properties

    /// The speech synthesizer instance
    private let synthesizer: AVSpeechSynthesizer

    /// Configuration for speech synthesis
    private let configuration: AppleSpeechSynthesisConfiguration

    /// The current utterance being spoken
    private var currentUtterance: AVSpeechUtterance?

    /// Total length of current text for progress calculation
    private var currentTextLength: Int = 0

    /// Continuation for the speak() async method
    private var speakContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Lifecycle

    /// Creates a new AppleSpeechSynthesisProvider with the specified configuration.
    /// - Parameter configuration: Configuration options (default: .default)
    public init(configuration: AppleSpeechSynthesisConfiguration = .default) {
        self.configuration = configuration
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
    }

    // MARK: - Public Methods

    public func speak(text: String, voice: String?) async throws {
        // Validate text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeechSynthesisProviderError.invalidText
        }

        // Stop any current speech
        if isPlaying || isPaused {
            stop()
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)

        // Configure voice
        if let voiceIdentifier = voice {
            guard let selectedVoice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else {
                throw SpeechSynthesisProviderError.voiceNotAvailable(voiceIdentifier)
            }
            utterance.voice = selectedVoice
        } else {
            // Use default voice for current locale
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier)
        }

        // Apply configuration
        utterance.rate = configuration.rate
        utterance.pitchMultiplier = configuration.pitchMultiplier
        utterance.volume = configuration.volume
        utterance.preUtteranceDelay = configuration.preUtteranceDelay
        utterance.postUtteranceDelay = configuration.postUtteranceDelay

        // Store current utterance info
        currentUtterance = utterance
        currentTextLength = text.count

        // Speak and wait for completion
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.speakContinuation = continuation
            self.synthesizer.speak(utterance)
        }
    }

    public func stop() {
        guard isPlaying || isPaused else { return }

        synthesizer.stopSpeaking(at: .immediate)

        // State will be updated in delegate callback
    }

    public func pause() {
        guard isPlaying, !isPaused else { return }

        synthesizer.pauseSpeaking(at: .immediate)

        // State will be updated in delegate callback
    }

    public func resume() {
        guard isPaused else { return }

        synthesizer.continueSpeaking()

        // State will be updated in delegate callback
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AppleSpeechSynthesisProvider: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = true
            self.isPaused = false
            self.eventsContinuation?.yield(.started)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.isPaused = true
            self.eventsContinuation?.yield(.paused)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = true
            self.isPaused = false
            self.eventsContinuation?.yield(.resumed)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.isPaused = false
            self.currentUtterance = nil
            self.eventsContinuation?.yield(.completed)
            self.speakContinuation?.resume(returning: ())
            self.speakContinuation = nil
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.isPaused = false
            self.currentUtterance = nil
            // Emit cancelled event before resuming continuation
            self.eventsContinuation?.yield(.failed(.cancelled))
            self.speakContinuation?.resume(throwing: SpeechSynthesisProviderError.cancelled)
            self.speakContinuation = nil
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.currentTextLength > 0 else { return }
            // Use location for accurate progress (end of range would show 100% too early)
            let progress = Float(characterRange.location) / Float(self.currentTextLength)
            self.eventsContinuation?.yield(.progress(min(max(progress, 0.0), 1.0)))
        }
    }
}

#else

// MARK: - Stub for platforms without AVFoundation

import Foundation

/// Stub implementation for platforms without AVFoundation.
@Observable
@MainActor
public final class AppleSpeechSynthesisProvider: SpeechSynthesisProvider {
    public static let identifier: String = "com.apple.avspeechsynthesizer"
    public static var isAvailable: Bool { false }

    public private(set) var isPlaying: Bool = false
    public private(set) var isPaused: Bool = false
    public var capabilities: Set<SpeechSynthesisCapability> { [] }

    public var events: AsyncStream<SpeechSynthesisEvent> {
        AsyncStream { $0.finish() }
    }

    public init(configuration: AppleSpeechSynthesisConfiguration = .default) {}

    public func speak(text: String, voice: String?) async throws {
        throw SpeechSynthesisProviderError.providerNotAvailable(.apple)
    }

    public func stop() {}
    public func pause() {}
    public func resume() {}
}

/// Stub configuration for platforms without AVFoundation.
public struct AppleSpeechSynthesisConfiguration: Sendable {
    public let rate: Float
    public let pitchMultiplier: Float
    public let volume: Float
    public let preUtteranceDelay: TimeInterval
    public let postUtteranceDelay: TimeInterval

    public init(
        rate: Float = 0.5,
        pitchMultiplier: Float = 1.0,
        volume: Float = 1.0,
        preUtteranceDelay: TimeInterval = 0.0,
        postUtteranceDelay: TimeInterval = 0.0
    ) {
        self.rate = rate
        self.pitchMultiplier = pitchMultiplier
        self.volume = volume
        self.preUtteranceDelay = preUtteranceDelay
        self.postUtteranceDelay = postUtteranceDelay
    }

    public static let `default` = AppleSpeechSynthesisConfiguration()
}

#endif
