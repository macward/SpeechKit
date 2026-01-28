import Foundation

// MARK: - MockSpeechRecognitionProvider

/// Mock speech recognition provider for testing purposes.
///
/// This provider allows simulating speech recognition behavior in tests
/// without requiring actual microphone access or speech recognition services.
///
/// ## Usage
/// ```swift
/// let mockProvider = MockSpeechRecognitionProvider()
/// let engine = SpeechRecognitionEngine(provider: mockProvider)
///
/// // Simulate authorization
/// mockProvider.authorizationStatus = .authorized
///
/// // Start listening
/// try await engine.startListening(locale: .current)
///
/// // Simulate speech results
/// mockProvider.simulatePartialResult("Hello")
/// mockProvider.simulateFinalResult("Hello world")
/// ```
@Observable
@MainActor
public final class MockSpeechRecognitionProvider: SpeechRecognitionProvider {
    // MARK: - Type Properties

    public static let identifier: String = "com.speechkit.mock"

    public static var isAvailable: Bool { true }

    // MARK: - Instance Properties

    public private(set) var isListening: Bool = false
    public var authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    public private(set) var partialTranscription: String = ""

    /// Stream continuation for emitting results
    private var resultsContinuation: AsyncStream<SpeechRecognitionResult>.Continuation?

    /// The results stream (created once at init to ensure single continuation)
    public private(set) var results: AsyncStream<SpeechRecognitionResult>

    // MARK: - Test Hooks

    /// Number of times `requestAuthorization` was called
    public private(set) var requestAuthorizationCallCount: Int = 0

    /// Number of times `startListening` was called
    public private(set) var startListeningCallCount: Int = 0

    /// Number of times `stopListening` was called
    public private(set) var stopListeningCallCount: Int = 0

    /// The last locale passed to `startListening`
    public private(set) var lastRequestedLocale: Locale?

    /// Error to throw when `startListening` is called
    public var startListeningError: SpeechRecognitionError?

    /// Status to return from `requestAuthorization`
    public var authorizationStatusToReturn: SpeechAuthorizationStatus = .authorized

    // MARK: - Lifecycle

    public init() {
        // Create results stream once to ensure single continuation
        // Using makeStream() for clean initialization
        let (stream, continuation) = AsyncStream.makeStream(of: SpeechRecognitionResult.self)
        self.results = stream
        self.resultsContinuation = continuation
    }

    // MARK: - Public Methods

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        requestAuthorizationCallCount += 1
        authorizationStatus = authorizationStatusToReturn
        return authorizationStatusToReturn
    }

    public func startListening(locale: Locale = .current) async throws {
        startListeningCallCount += 1
        lastRequestedLocale = locale

        if let error = startListeningError {
            throw error
        }

        guard authorizationStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }

        isListening = true
        partialTranscription = ""
    }

    public func stopListening() {
        stopListeningCallCount += 1
        isListening = false
        resultsContinuation?.finish()
    }

    // MARK: - Simulation Methods

    /// Simulates receiving a partial transcription result.
    /// - Parameter text: The partial transcription text
    public func simulatePartialResult(_ text: String) {
        guard isListening else { return }
        partialTranscription = text
        let result = SpeechRecognitionResult(
            text: text,
            isFinal: false,
            confidence: 0.5
        )
        resultsContinuation?.yield(result)
    }

    /// Simulates receiving a final transcription result.
    /// - Parameters:
    ///   - text: The final transcription text
    ///   - confidence: The confidence level (default: 1.0)
    public func simulateFinalResult(_ text: String, confidence: Float = 1.0) {
        guard isListening else { return }
        partialTranscription = text
        let result = SpeechRecognitionResult(
            text: text,
            isFinal: true,
            confidence: confidence
        )
        resultsContinuation?.yield(result)
    }

    /// Simulates an error during recognition.
    /// - Parameter error: The error to simulate
    public func simulateError(_ error: SpeechRecognitionError) {
        guard isListening else { return }
        stopListening()
    }

    /// Resets all test hooks and state.
    public func reset() {
        requestAuthorizationCallCount = 0
        startListeningCallCount = 0
        stopListeningCallCount = 0
        lastRequestedLocale = nil
        startListeningError = nil
        authorizationStatusToReturn = .authorized
        authorizationStatus = .notDetermined
        isListening = false
        partialTranscription = ""
    }
}
