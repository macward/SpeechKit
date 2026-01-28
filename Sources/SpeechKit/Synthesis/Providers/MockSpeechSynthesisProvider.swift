import Foundation

// MARK: - MockSpeechSynthesisProvider

/// Mock speech synthesis provider for testing purposes.
///
/// This provider allows simulating speech synthesis behavior in tests
/// without requiring actual audio playback.
///
/// ## Usage
/// ```swift
/// let mockProvider = MockSpeechSynthesisProvider()
/// let engine = SpeechSynthesisEngine(provider: mockProvider)
///
/// // Speak text
/// Task {
///     try await engine.speak(text: "Hello")
/// }
///
/// // Simulate completion
/// mockProvider.simulateCompletion()
/// ```
@Observable
@MainActor
public final class MockSpeechSynthesisProvider: SpeechSynthesisProvider {
    // MARK: - Type Properties

    public static let identifier: String = "com.speechkit.mock.synthesis"

    public static var isAvailable: Bool { true }

    // MARK: - Instance Properties

    public private(set) var isPlaying: Bool = false
    public private(set) var isPaused: Bool = false

    public var capabilities: Set<SpeechSynthesisCapability> {
        mockCapabilities
    }

    /// Configurable capabilities for testing
    public var mockCapabilities: Set<SpeechSynthesisCapability> = [.pause, .resume, .offline]

    /// Stream continuation for emitting events
    private var eventsContinuation: AsyncStream<SpeechSynthesisEvent>.Continuation?

    /// The events stream (created once at init to ensure single continuation)
    public private(set) var events: AsyncStream<SpeechSynthesisEvent>

    // MARK: - Test Hooks

    /// Number of times `speak` was called
    public private(set) var speakCallCount: Int = 0

    /// Number of times `stop` was called
    public private(set) var stopCallCount: Int = 0

    /// Number of times `pause` was called
    public private(set) var pauseCallCount: Int = 0

    /// Number of times `resume` was called
    public private(set) var resumeCallCount: Int = 0

    /// The last text passed to `speak`
    public private(set) var lastSpokenText: String?

    /// The last voice passed to `speak`
    public private(set) var lastRequestedVoice: String?

    /// Error to throw when `speak` is called
    public var speakError: SpeechSynthesisProviderError?

    /// Whether to auto-complete speak() immediately
    public var autoComplete: Bool = true

    /// Continuation for manually completing speak()
    private var speakContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Lifecycle

    public init() {
        // Create events stream once to ensure single continuation
        // Using makeStream() for clean initialization
        let (stream, continuation) = AsyncStream.makeStream(of: SpeechSynthesisEvent.self)
        self.events = stream
        self.eventsContinuation = continuation
    }

    // MARK: - Public Methods

    public func speak(text: String, voice: String?) async throws {
        speakCallCount += 1
        lastSpokenText = text
        lastRequestedVoice = voice

        // Validate text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeechSynthesisProviderError.invalidText
        }

        if let error = speakError {
            eventsContinuation?.yield(.failed(error))
            throw error
        }

        isPlaying = true
        isPaused = false
        eventsContinuation?.yield(.started)

        if autoComplete {
            // Simulate immediate completion
            isPlaying = false
            eventsContinuation?.yield(.completed)
        } else {
            // Wait for manual completion
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.speakContinuation = continuation
            }
        }
    }

    public func stop() {
        stopCallCount += 1
        guard isPlaying || isPaused else { return }

        isPlaying = false
        isPaused = false
        eventsContinuation?.yield(.failed(.cancelled))
        speakContinuation?.resume(throwing: SpeechSynthesisProviderError.cancelled)
        speakContinuation = nil
    }

    public func pause() {
        pauseCallCount += 1
        guard isPlaying, !isPaused else { return }

        isPlaying = false
        isPaused = true
        eventsContinuation?.yield(.paused)
    }

    public func resume() {
        resumeCallCount += 1
        guard isPaused else { return }

        isPlaying = true
        isPaused = false
        eventsContinuation?.yield(.resumed)
    }

    // MARK: - Simulation Methods

    /// Simulates speech completion.
    public func simulateCompletion() {
        guard isPlaying || isPaused else { return }

        isPlaying = false
        isPaused = false
        eventsContinuation?.yield(.completed)
        speakContinuation?.resume(returning: ())
        speakContinuation = nil
    }

    /// Simulates progress during speech.
    /// - Parameter progress: Progress value from 0.0 to 1.0
    public func simulateProgress(_ progress: Float) {
        guard isPlaying else { return }
        eventsContinuation?.yield(.progress(progress))
    }

    /// Simulates an error during speech.
    /// - Parameter error: The error to simulate
    public func simulateError(_ error: SpeechSynthesisProviderError) {
        guard isPlaying || isPaused else { return }

        isPlaying = false
        isPaused = false
        eventsContinuation?.yield(.failed(error))
        speakContinuation?.resume(throwing: error)
        speakContinuation = nil
    }

    /// Resets all test hooks and state.
    public func reset() {
        speakCallCount = 0
        stopCallCount = 0
        pauseCallCount = 0
        resumeCallCount = 0
        lastSpokenText = nil
        lastRequestedVoice = nil
        speakError = nil
        autoComplete = true
        isPlaying = false
        isPaused = false
        mockCapabilities = [.pause, .resume, .offline]
        speakContinuation = nil
    }
}
