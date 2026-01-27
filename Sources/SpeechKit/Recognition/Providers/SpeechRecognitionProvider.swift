import Foundation

// MARK: - Provider Type

/// Available speech recognition provider types.
public enum SpeechRecognitionProviderType: String, Sendable, CaseIterable {
    /// Automatically select the best available provider
    case auto

    /// Apple's legacy SFSpeechRecognizer (iOS 10+, macOS 10.15+)
    case sfSpeechRecognizer

    /// Apple's modern SpeechAnalyzer (iOS 26+, macOS 26+)
    case speechAnalyzer
}

// MARK: - Provider Protocol

/// Protocol defining the interface for speech recognition providers.
///
/// Providers encapsulate specific speech recognition implementations,
/// allowing the `SpeechRecognitionEngine` to swap between different
/// backends transparently.
///
/// Conforming types must be `@MainActor` to ensure thread-safe
/// integration with SwiftUI and Observable patterns.
@MainActor
public protocol SpeechRecognitionProvider: AnyObject {
    // MARK: - Type Properties

    /// Unique identifier for this provider type
    static var identifier: String { get }

    /// Whether this provider is available on the current platform
    static var isAvailable: Bool { get }

    // MARK: - Instance Properties

    /// Whether the provider is currently listening for speech
    var isListening: Bool { get }

    /// Current authorization status for speech recognition
    var authorizationStatus: SpeechAuthorizationStatus { get }

    /// The current partial transcription being recognized
    var partialTranscription: String { get }

    /// Stream of recognition results
    ///
    /// Consumers can iterate over this stream to receive real-time
    /// transcription updates. The stream emits both partial and final results.
    var results: AsyncStream<SpeechRecognitionResult> { get }

    // MARK: - Methods

    /// Requests authorization for speech recognition and microphone access.
    /// - Returns: The resulting authorization status
    func requestAuthorization() async -> SpeechAuthorizationStatus

    /// Starts listening for speech input.
    /// - Parameter locale: The locale for speech recognition (default: current)
    /// - Throws: `SpeechRecognitionError` if recognition cannot start
    func startListening(locale: Locale) async throws

    /// Stops listening for speech input.
    func stopListening()
}

// MARK: - Provider Errors

/// Errors specific to provider operations.
public enum SpeechRecognitionProviderError: Error, Sendable {
    /// The requested provider is not available on this platform
    case providerNotAvailable(SpeechRecognitionProviderType)

    /// Failed to initialize the provider
    case initializationFailed(String)

    /// The provider requires a model download before use
    case modelDownloadRequired(locale: Locale)
}
