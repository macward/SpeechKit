import Foundation

// MARK: - Protocol

/// Protocol defining the interface for speech recognition.
@MainActor
public protocol SpeechRecognitionEngineProtocol: AnyObject {
    /// Whether the engine is currently listening
    var isListening: Bool { get }

    /// Current authorization status
    var authorizationStatus: SpeechAuthorizationStatus { get }

    /// The current partial transcription (updated in real-time)
    var partialTranscription: String { get }

    /// The last final transcription result
    var lastResult: SpeechRecognitionResult? { get }

    /// The current error, if any
    var error: SpeechRecognitionError? { get }

    /// Requests authorization for speech recognition and microphone
    func requestAuthorization() async -> SpeechAuthorizationStatus

    /// Starts listening for speech
    /// - Parameter locale: The locale for recognition (default: current)
    func startListening(locale: Locale) async throws

    /// Stops listening for speech
    func stopListening()
}

// MARK: - Implementation

/// Engine for continuous speech recognition using a provider-based architecture.
///
/// The engine coordinates between different speech recognition providers,
/// automatically selecting the best available provider or allowing manual selection.
///
/// Example usage:
/// ```swift
/// let engine = SpeechRecognitionEngine()
/// let status = await engine.requestAuthorization()
/// if status == .authorized {
///     try await engine.startListening(locale: Locale(identifier: "en-US"))
///     // Observe partialTranscription and lastResult
/// }
/// ```
@Observable
@MainActor
public final class SpeechRecognitionEngine: SpeechRecognitionEngineProtocol {
    // MARK: - Properties

    /// The active speech recognition provider
    private let provider: any SpeechRecognitionProvider

    /// The type of provider being used
    public let providerType: SpeechRecognitionProviderType

    /// Task for consuming the results stream
    private var resultsTask: Task<Void, Never>?

    /// Whether the engine is currently listening
    public var isListening: Bool {
        provider.isListening
    }

    /// Current authorization status
    public var authorizationStatus: SpeechAuthorizationStatus {
        provider.authorizationStatus
    }

    /// The current partial transcription (updated in real-time)
    public var partialTranscription: String {
        provider.partialTranscription
    }

    /// The last final transcription result
    public private(set) var lastResult: SpeechRecognitionResult?

    /// The current error, if any
    public private(set) var error: SpeechRecognitionError?

    /// Callback when final transcription is ready
    public var onFinalTranscription: ((SpeechRecognitionResult) -> Void)?

    // MARK: - Lifecycle

    /// Creates a new SpeechRecognitionEngine with the specified provider type.
    /// - Parameters:
    ///   - providerType: The type of provider to use (default: .auto)
    ///   - silenceThreshold: Seconds of silence before speech is considered ended (default: 1.5)
    public init(
        providerType: SpeechRecognitionProviderType = .auto,
        silenceThreshold: TimeInterval = 1.5
    ) {
        let (resolvedType, provider) = Self.createProvider(
            requestedType: providerType,
            silenceThreshold: silenceThreshold
        )
        self.providerType = resolvedType
        self.provider = provider
    }

    /// Creates a new SpeechRecognitionEngine with a custom provider.
    /// - Parameter provider: The provider instance to use
    public init(provider: any SpeechRecognitionProvider) {
        self.provider = provider
        // Determine type from provider identifier
        switch type(of: provider).identifier {
        case SFSpeechRecognizerProvider.identifier:
            self.providerType = .sfSpeechRecognizer
        default:
            self.providerType = .auto
        }
    }

    // MARK: - Public Methods

    /// Requests authorization for speech recognition and microphone.
    /// - Returns: The resulting authorization status
    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        await provider.requestAuthorization()
    }

    /// Starts listening for speech.
    /// - Parameter locale: The locale for recognition (default: current)
    /// - Throws: `SpeechRecognitionError` if recognition cannot start
    public func startListening(locale: Locale = .current) async throws {
        // Reset state
        error = nil
        lastResult = nil

        // Start the provider FIRST - this creates a fresh results stream
        // (AsyncStream is single-consumer, so provider creates new stream each session)
        try await provider.startListening(locale: locale)

        // THEN start consuming results - now we get the new stream reference
        startResultsConsumer()
    }

    /// Stops listening for speech.
    public func stopListening() {
        resultsTask?.cancel()
        resultsTask = nil
        provider.stopListening()
    }

    // MARK: - Private Methods

    private static func createProvider(
        requestedType: SpeechRecognitionProviderType,
        silenceThreshold: TimeInterval
    ) -> (SpeechRecognitionProviderType, any SpeechRecognitionProvider) {
        switch requestedType {
        case .auto:
            // For now, always use SFSpeechRecognizer
            // SpeechAnalyzer will be added when iOS 26 is available
            if SFSpeechRecognizerProvider.isAvailable {
                return (.sfSpeechRecognizer, SFSpeechRecognizerProvider(silenceThreshold: silenceThreshold))
            }
            // Fallback to SFSpeechRecognizer even if not "available" (will fail gracefully)
            return (.sfSpeechRecognizer, SFSpeechRecognizerProvider(silenceThreshold: silenceThreshold))

        case .sfSpeechRecognizer:
            return (.sfSpeechRecognizer, SFSpeechRecognizerProvider(silenceThreshold: silenceThreshold))

        case .speechAnalyzer:
            // SpeechAnalyzer requires iOS 26+/macOS 26+
            // Check availability and fall back to SFSpeechRecognizer if not available
            if #available(iOS 26, macOS 26, visionOS 3, *) {
                // Note: SpeechAnalyzerProvider is currently a placeholder
                // Once implemented, it will be returned here
                // For now, fall back to SFSpeechRecognizer
                return (.sfSpeechRecognizer, SFSpeechRecognizerProvider(silenceThreshold: silenceThreshold))
            }
            // Platform doesn't support SpeechAnalyzer, use SFSpeechRecognizer
            return (.sfSpeechRecognizer, SFSpeechRecognizerProvider(silenceThreshold: silenceThreshold))
        }
    }

    private func startResultsConsumer() {
        resultsTask?.cancel()
        resultsTask = Task { [weak self] in
            guard let self else { return }
            for await result in self.provider.results {
                guard !Task.isCancelled else { break }
                self.handleResult(result)
            }
        }
    }

    private func handleResult(_ result: SpeechRecognitionResult) {
        if result.isFinal {
            lastResult = result
            onFinalTranscription?(result)
        }
    }
}
