import Foundation

// MARK: - Provider Type

/// Available speech synthesis provider types.
///
/// Each type represents a different TTS backend with its own characteristics:
/// - `auto`: System selects the best available provider
/// - `apple`: Uses AVSpeechSynthesizer (offline capable, free)
/// - `elevenLabs`: High-quality AI voices (streaming, requires internet)
/// - `openAI`: OpenAI TTS API (multiple voices, requires internet)
/// - `localTTS`: Fully offline with local models
public enum SpeechSynthesisProviderType: String, Sendable, CaseIterable {
    /// Automatically select the best available provider
    case auto

    /// Apple's built-in AVSpeechSynthesizer
    case apple

    /// ElevenLabs high-quality AI voices
    case elevenLabs

    /// OpenAI Text-to-Speech API
    case openAI

    /// Local TTS with offline models
    case localTTS
}

// MARK: - Capabilities

/// Capabilities that a speech synthesis provider may support.
///
/// Use these to query provider features before attempting operations
/// that may not be available on all providers.
public enum SpeechSynthesisCapability: String, Sendable, CaseIterable {
    /// Provider supports pausing speech playback
    case pause

    /// Provider supports resuming paused speech
    case resume

    /// Provider supports streaming audio as it's generated
    case streaming

    /// Provider can work without internet connection
    case offline
}

// MARK: - Events

/// Events emitted by a speech synthesis provider during playback.
///
/// Subscribe to the provider's `events` stream to receive real-time
/// updates about synthesis and playback state.
public enum SpeechSynthesisEvent: Sendable {
    /// Speech synthesis and playback has started
    case started

    /// Progress update during synthesis or playback
    /// - Parameter progress: Value from 0.0 to 1.0 indicating completion percentage
    case progress(Float)

    /// Speech playback was paused
    case paused

    /// Speech playback was resumed after being paused
    case resumed

    /// Speech playback completed successfully
    case completed

    /// An error occurred during synthesis or playback
    /// - Parameter error: The error that occurred
    case failed(SpeechSynthesisProviderError)
}

// MARK: - Errors

/// Errors that can occur during speech synthesis operations.
public enum SpeechSynthesisProviderError: Error, Sendable, Equatable {
    /// The requested provider is not available on this platform
    case providerNotAvailable(SpeechSynthesisProviderType)

    /// Failed to initialize the provider
    case initializationFailed(String)

    /// The provided text is empty or invalid
    case invalidText

    /// The requested voice is not available
    case voiceNotAvailable(String)

    /// Network connection is required but not available
    case networkUnavailable

    /// API authentication failed (invalid or missing credentials)
    case authenticationFailed

    /// API rate limit exceeded
    case rateLimitExceeded

    /// Audio playback failed
    case playbackFailed(String)

    /// The synthesis operation was cancelled
    case cancelled

    /// An unknown error occurred
    case unknown(String)
}

// MARK: - Provider Protocol

/// Protocol defining the interface for speech synthesis providers.
///
/// Providers encapsulate specific text-to-speech implementations,
/// allowing the `SpeechSynthesisEngine` to swap between different
/// backends transparently.
///
/// Conforming types must be `@MainActor` to ensure thread-safe
/// integration with SwiftUI and Observable patterns.
///
/// ## Example Usage
///
/// ```swift
/// let provider = AppleSpeechSynthesisProvider()
///
/// // Check capabilities before using optional features
/// if provider.capabilities.contains(.pause) {
///     // Safe to call pause/resume
/// }
///
/// // Subscribe to events
/// Task {
///     for await event in provider.events {
///         switch event {
///         case .started:
///             print("Speaking...")
///         case .progress(let value):
///             print("Progress: \(value * 100)%")
///         case .completed:
///             print("Done!")
///         case .failed(let error):
///             print("Error: \(error)")
///         default:
///             break
///         }
///     }
/// }
///
/// // Start speaking
/// try await provider.speak(text: "Hello, world!")
/// ```
@MainActor
public protocol SpeechSynthesisProvider: AnyObject {
    // MARK: - Type Properties

    /// Unique identifier for this provider type.
    ///
    /// Used to identify the provider in logs and for persistence.
    static var identifier: String { get }

    /// Whether this provider is available on the current platform.
    ///
    /// Check this before attempting to create an instance of the provider.
    /// A provider may be unavailable due to:
    /// - Missing platform support
    /// - Missing required frameworks
    /// - Missing API credentials
    static var isAvailable: Bool { get }

    // MARK: - Instance Properties

    /// Whether the provider is currently playing speech.
    ///
    /// This is `true` when audio is actively being played,
    /// and `false` when idle, paused, or stopped.
    var isPlaying: Bool { get }

    /// Whether the provider is currently paused.
    ///
    /// This is `true` only when speech was paused via `pause()`.
    /// Check `capabilities` for `.pause` support before relying on this.
    var isPaused: Bool { get }

    /// The set of capabilities supported by this provider.
    ///
    /// Use this to check for optional features before attempting
    /// to use them. For example:
    /// ```swift
    /// if provider.capabilities.contains(.pause) {
    ///     provider.pause()
    /// }
    /// ```
    var capabilities: Set<SpeechSynthesisCapability> { get }

    /// Stream of events emitted during speech synthesis and playback.
    ///
    /// Subscribe to this stream to receive real-time updates about
    /// the provider's state. The stream emits events for:
    /// - Playback start, pause, resume, and completion
    /// - Progress updates during synthesis
    /// - Errors that occur during operation
    ///
    /// The stream remains active for the lifetime of the provider.
    var events: AsyncStream<SpeechSynthesisEvent> { get }

    // MARK: - Methods

    /// Synthesizes and plays the given text as speech.
    ///
    /// This method is async and supports Task cancellation. When cancelled,
    /// playback stops immediately and a `.cancelled` error is thrown.
    ///
    /// - Parameters:
    ///   - text: The text to synthesize and speak
    ///   - voice: Voice identifier specific to the provider, or `nil` for default
    /// - Throws: `SpeechSynthesisProviderError` if synthesis or playback fails
    func speak(text: String, voice: String?) async throws

    /// Stops speech playback immediately.
    ///
    /// This method is synchronous and returns immediately.
    /// Any ongoing synthesis or playback is cancelled.
    /// After calling `stop()`, `isPlaying` will be `false`.
    func stop()

    /// Pauses speech playback.
    ///
    /// Only available if `capabilities` contains `.pause`.
    /// Has no effect if not currently playing or already paused.
    /// After calling `pause()`, `isPaused` will be `true`.
    func pause()

    /// Resumes speech playback after being paused.
    ///
    /// Only available if `capabilities` contains `.resume`.
    /// Has no effect if not currently paused.
    /// After calling `resume()`, `isPaused` will be `false`.
    func resume()
}

// MARK: - Default Implementations

public extension SpeechSynthesisProvider {
    /// Speaks text using the default voice.
    ///
    /// Convenience method that calls `speak(text:voice:)` with `nil` voice.
    ///
    /// - Parameter text: The text to synthesize and speak
    /// - Throws: `SpeechSynthesisProviderError` if synthesis or playback fails
    func speak(text: String) async throws {
        try await speak(text: text, voice: nil)
    }

    /// Default no-op implementation for providers that don't support pause.
    ///
    /// Override this method if your provider supports the `.pause` capability.
    func pause() {
        // No-op for providers without pause capability
    }

    /// Default no-op implementation for providers that don't support resume.
    ///
    /// Override this method if your provider supports the `.resume` capability.
    func resume() {
        // No-op for providers without resume capability
    }
}
