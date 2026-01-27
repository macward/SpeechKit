import Foundation

// MARK: - Protocol

/// Protocol defining the interface for speech synthesis.
///
/// This protocol allows for dependency injection and testing
/// of components that depend on speech synthesis functionality.
@MainActor
public protocol SpeechSynthesisEngineProtocol: AnyObject {
    /// Whether the engine is currently playing speech
    var isPlaying: Bool { get }

    /// Whether the engine is currently paused
    var isPaused: Bool { get }

    /// The set of capabilities supported by the active provider
    var capabilities: Set<SpeechSynthesisCapability> { get }

    /// Stream of events emitted during speech synthesis
    var events: AsyncStream<SpeechSynthesisEvent> { get }

    /// Synthesizes and plays the given text as speech.
    /// - Parameters:
    ///   - text: The text to synthesize and speak
    ///   - voice: Voice identifier specific to the provider, or `nil` for default
    /// - Throws: `SpeechSynthesisProviderError` if synthesis fails
    func speak(text: String, voice: String?) async throws

    /// Stops speech playback immediately.
    func stop()

    /// Pauses speech playback if supported by the provider.
    func pause()

    /// Resumes speech playback after being paused.
    func resume()
}

// MARK: - Implementation

/// Engine for speech synthesis using a provider-based architecture.
///
/// The engine coordinates between different speech synthesis providers,
/// automatically selecting the best available provider or allowing manual selection.
/// If the primary provider fails, it automatically falls back to `AppleSpeechSynthesisProvider`.
///
/// ## Example Usage
///
/// ```swift
/// let engine = SpeechSynthesisEngine()
///
/// // Subscribe to events
/// Task {
///     for await event in engine.events {
///         switch event {
///         case .started:
///             print("Speaking...")
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
/// // Speak text
/// try await engine.speak(text: "Hello, world!")
/// ```
@Observable
@MainActor
public final class SpeechSynthesisEngine: SpeechSynthesisEngineProtocol {
    // MARK: - Properties

    /// The active speech synthesis provider
    private var provider: any SpeechSynthesisProvider

    /// The type of provider being used
    public private(set) var providerType: SpeechSynthesisProviderType

    /// Whether the engine is currently playing speech
    public var isPlaying: Bool {
        provider.isPlaying
    }

    /// Whether the engine is currently paused
    public var isPaused: Bool {
        provider.isPaused
    }

    /// The set of capabilities supported by the active provider
    public var capabilities: Set<SpeechSynthesisCapability> {
        provider.capabilities
    }

    /// Stream of events emitted during speech synthesis
    public var events: AsyncStream<SpeechSynthesisEvent> {
        provider.events
    }

    /// The current error, if any
    public private(set) var error: SpeechSynthesisProviderError?

    /// Whether fallback is enabled when primary provider fails
    public let fallbackEnabled: Bool

    // MARK: - Lifecycle

    /// Creates a new SpeechSynthesisEngine with the specified provider type.
    /// - Parameters:
    ///   - providerType: The type of provider to use (default: .auto)
    ///   - fallbackEnabled: Whether to fallback to Apple provider on failure (default: true)
    public init(
        providerType: SpeechSynthesisProviderType = .auto,
        fallbackEnabled: Bool = true
    ) {
        let (resolvedType, provider) = Self.createProvider(requestedType: providerType)
        self.providerType = resolvedType
        self.provider = provider
        self.fallbackEnabled = fallbackEnabled
    }

    /// Creates a new SpeechSynthesisEngine with a custom provider.
    /// - Parameters:
    ///   - provider: The provider instance to use
    ///   - fallbackEnabled: Whether to fallback to Apple provider on failure (default: true)
    public init(
        provider: any SpeechSynthesisProvider,
        fallbackEnabled: Bool = true
    ) {
        self.provider = provider
        self.fallbackEnabled = fallbackEnabled
        // Determine type from provider identifier
        switch type(of: provider).identifier {
        case AppleSpeechSynthesisProvider.identifier:
            self.providerType = .apple
        default:
            self.providerType = .auto
        }
    }

    // MARK: - Public Methods

    /// Synthesizes and plays the given text as speech.
    ///
    /// If the primary provider fails and `fallbackEnabled` is true,
    /// automatically retries with `AppleSpeechSynthesisProvider`.
    ///
    /// - Parameters:
    ///   - text: The text to synthesize and speak
    ///   - voice: Voice identifier specific to the provider, or `nil` for default
    /// - Throws: `SpeechSynthesisProviderError` if synthesis fails (including fallback)
    public func speak(text: String, voice: String? = nil) async throws {
        error = nil

        do {
            try await provider.speak(text: text, voice: voice)
        } catch let providerError as SpeechSynthesisProviderError {
            // Don't fallback for user-initiated cancellation or invalid input
            guard fallbackEnabled,
                  providerError != .cancelled,
                  providerError != .invalidText,
                  !isAppleProvider else {
                error = providerError
                throw providerError
            }

            // Attempt fallback to Apple provider
            try await fallbackToAppleProvider(text: text, originalError: providerError)
        }
        // Non-SpeechSynthesisProviderError errors propagate naturally
    }

    /// Stops speech playback immediately.
    public func stop() {
        provider.stop()
    }

    /// Pauses speech playback if supported by the provider.
    ///
    /// Has no effect if the provider doesn't support the `.pause` capability.
    /// Check `capabilities.contains(.pause)` before calling if you need
    /// to know whether pause is supported.
    public func pause() {
        guard capabilities.contains(.pause) else { return }
        provider.pause()
    }

    /// Resumes speech playback after being paused.
    ///
    /// Has no effect if the provider doesn't support the `.resume` capability.
    /// Check `capabilities.contains(.resume)` before calling if you need
    /// to know whether resume is supported.
    public func resume() {
        guard capabilities.contains(.resume) else { return }
        provider.resume()
    }

    // MARK: - Private Methods

    /// Whether the current provider is AppleSpeechSynthesisProvider
    private var isAppleProvider: Bool {
        type(of: provider).identifier == AppleSpeechSynthesisProvider.identifier
    }

    /// Creates a provider based on the requested type.
    private static func createProvider(
        requestedType: SpeechSynthesisProviderType
    ) -> (SpeechSynthesisProviderType, any SpeechSynthesisProvider) {
        switch requestedType {
        case .auto:
            // Default to Apple provider (always available, offline, free)
            return (.apple, AppleSpeechSynthesisProvider())

        case .apple:
            return (.apple, AppleSpeechSynthesisProvider())

        case .elevenLabs:
            // ElevenLabs provider not implemented yet, fallback to Apple
            return (.apple, AppleSpeechSynthesisProvider())

        case .openAI:
            // OpenAI provider not implemented yet, fallback to Apple
            return (.apple, AppleSpeechSynthesisProvider())

        case .localTTS:
            // LocalTTS provider not implemented yet, fallback to Apple
            return (.apple, AppleSpeechSynthesisProvider())
        }
    }

    /// Attempts to speak using AppleSpeechSynthesisProvider as fallback.
    private func fallbackToAppleProvider(
        text: String,
        originalError: SpeechSynthesisProviderError
    ) async throws {
        // Create fallback provider
        let fallbackProvider = AppleSpeechSynthesisProvider()

        // Update state to use fallback
        provider = fallbackProvider
        providerType = .apple

        do {
            try await fallbackProvider.speak(text: text, voice: nil)
        } catch let fallbackError as SpeechSynthesisProviderError {
            // Fallback also failed, report original error
            error = originalError
            throw originalError
        } catch {
            // Unexpected error during fallback
            self.error = originalError
            throw originalError
        }
    }
}

// MARK: - Convenience Extensions

public extension SpeechSynthesisEngineProtocol {
    /// Speaks text using the default voice.
    ///
    /// Convenience method that calls `speak(text:voice:)` with `nil` voice.
    ///
    /// - Parameter text: The text to synthesize and speak
    /// - Throws: `SpeechSynthesisProviderError` if synthesis fails
    func speak(text: String) async throws {
        try await speak(text: text, voice: nil)
    }
}
