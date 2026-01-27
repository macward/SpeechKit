import Foundation

/// The result of a speech recognition transcription.
public struct SpeechRecognitionResult: Sendable, Equatable {
    /// The transcribed text
    public let text: String

    /// Whether this is a final result (user stopped speaking)
    public let isFinal: Bool

    /// Confidence level of the transcription (0.0 to 1.0)
    public let confidence: Float

    /// When this result was generated
    public let timestamp: Date

    /// Creates a new speech recognition result
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - isFinal: Whether this is a final result
    ///   - confidence: Confidence level (0.0 to 1.0)
    ///   - timestamp: When generated (default: now)
    public init(
        text: String,
        isFinal: Bool,
        confidence: Float = 1.0,
        timestamp: Date = Date()
    ) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - Authorization Status

/// Authorization status for speech recognition.
public enum SpeechAuthorizationStatus: Sendable, Equatable {
    /// Authorization not yet requested
    case notDetermined

    /// User denied authorization
    case denied

    /// Authorization restricted by device policy
    case restricted

    /// Authorization granted
    case authorized
}

// MARK: - Recognition Error

/// Errors that can occur during speech recognition.
public enum SpeechRecognitionError: Error, Sendable, Equatable {
    /// Speech recognition is not available on this device
    case notAvailable

    /// User denied microphone or speech recognition permission
    case notAuthorized

    /// Audio engine failed to start
    case audioEngineError(String)

    /// Recognition request failed
    case recognitionFailed(String)

    /// Recognition was cancelled
    case cancelled
}
