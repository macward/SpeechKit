# API Reference

Complete API documentation for SpeechKit.

## Speech Recognition

### SpeechRecognitionEngine

Main entry point for speech recognition.

```swift
@Observable
@MainActor
public final class SpeechRecognitionEngine: SpeechRecognitionEngineProtocol
```

#### Initializers

```swift
/// Creates engine with default provider (SFSpeechRecognizer)
public init()

/// Creates engine with specific provider type
public init(
    providerType: SpeechRecognitionProviderType = .auto,
    silenceThreshold: TimeInterval = 1.5
)

/// Creates engine with custom provider
public init(provider: any SpeechRecognitionProvider)
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isListening` | `Bool` | Whether currently listening |
| `authorizationStatus` | `SpeechAuthorizationStatus` | Current authorization |
| `partialTranscription` | `String` | Current partial text |
| `lastResult` | `SpeechRecognitionResult?` | Most recent result |
| `error` | `SpeechRecognitionError?` | Last error |
| `providerType` | `SpeechRecognitionProviderType` | Active provider type |
| `results` | `AsyncStream<SpeechRecognitionResult>` | Result stream |

#### Methods

```swift
/// Request authorization for speech recognition
func requestAuthorization() async -> SpeechAuthorizationStatus

/// Start listening for speech
func startListening(locale: Locale) async throws

/// Stop listening
func stopListening()
```

---

### SpeechRecognitionResult

Recognition result containing transcription and metadata.

```swift
public struct SpeechRecognitionResult: Sendable, Equatable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | Transcribed text |
| `isFinal` | `Bool` | Whether this is final |
| `confidence` | `Float` | Confidence (0.0-1.0) |
| `timestamp` | `Date` | When generated |

#### Initializers

```swift
public init(
    text: String,
    isFinal: Bool,
    confidence: Float = 1.0,
    timestamp: Date = Date()
)
```

---

### SpeechRecognitionProviderType

Available recognition provider types.

```swift
public enum SpeechRecognitionProviderType: String, CaseIterable, Sendable {
    case auto               // Best available
    case sfSpeechRecognizer // Apple SFSpeechRecognizer
    case speechAnalyzer     // iOS 26+ SpeechAnalyzer
}
```

---

### SpeechAuthorizationStatus

Authorization status for speech recognition.

```swift
public enum SpeechAuthorizationStatus: Sendable, Equatable {
    case notDetermined  // Not yet requested
    case denied         // User denied
    case restricted     // Device restricted
    case authorized     // Authorized
}
```

---

### SpeechRecognitionError

Errors that can occur during recognition.

```swift
public enum SpeechRecognitionError: Error, Equatable, Sendable {
    case notAvailable                    // Recognition not available
    case notAuthorized                   // Not authorized
    case audioEngineError(String)        // Audio engine error
    case recognitionFailed(String)       // Recognition failed
    case cancelled                       // Cancelled by user
}
```

---

### SpeechRecognitionProvider Protocol

Protocol for recognition provider implementations.

```swift
@MainActor
public protocol SpeechRecognitionProvider: AnyObject {
    static var identifier: String { get }
    static var isAvailable: Bool { get }

    var isListening: Bool { get }
    var authorizationStatus: SpeechAuthorizationStatus { get }
    var partialTranscription: String { get }
    var results: AsyncStream<SpeechRecognitionResult> { get }

    func requestAuthorization() async -> SpeechAuthorizationStatus
    func startListening(locale: Locale) async throws
    func stopListening()
}
```

---

## Speech Synthesis

### SpeechSynthesisEngine

Main entry point for speech synthesis.

```swift
@Observable
@MainActor
public final class SpeechSynthesisEngine: SpeechSynthesisEngineProtocol
```

#### Initializers

```swift
/// Creates engine with default provider (Apple)
public init()

/// Creates engine with specific provider type
public init(
    providerType: SpeechSynthesisProviderType = .auto,
    fallbackEnabled: Bool = true
)

/// Creates engine with custom provider
public init(
    provider: any SpeechSynthesisProvider,
    fallbackEnabled: Bool = true
)
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isPlaying` | `Bool` | Whether playing |
| `isPaused` | `Bool` | Whether paused |
| `capabilities` | `Set<SpeechSynthesisCapability>` | Supported features |
| `providerType` | `SpeechSynthesisProviderType` | Active provider |
| `error` | `SpeechSynthesisProviderError?` | Last error |
| `fallbackEnabled` | `Bool` | Whether fallback enabled |
| `events` | `AsyncStream<SpeechSynthesisEvent>` | Event stream |

#### Methods

```swift
/// Speak text with optional voice
func speak(text: String, voice: String? = nil) async throws

/// Stop playback
func stop()

/// Pause playback (if supported)
func pause()

/// Resume playback (if supported)
func resume()
```

---

### SpeechSynthesisProviderType

Available synthesis provider types.

```swift
public enum SpeechSynthesisProviderType: String, CaseIterable, Sendable {
    case auto       // Best available
    case apple      // AppleSpeechSynthesisProvider
    case elevenLabs // ElevenLabs (future)
    case openAI     // OpenAI TTS (future)
    case localTTS   // Local models (future)
}
```

---

### SpeechSynthesisCapability

Capabilities a provider may support.

```swift
public enum SpeechSynthesisCapability: String, CaseIterable, Sendable {
    case pause      // Can pause playback
    case resume     // Can resume after pause
    case streaming  // Supports streaming audio
    case offline    // Works without internet
}
```

---

### SpeechSynthesisEvent

Events emitted during synthesis.

```swift
public enum SpeechSynthesisEvent: Sendable {
    case started                              // Playback started
    case progress(Float)                      // Progress (0.0-1.0)
    case paused                               // Playback paused
    case resumed                              // Playback resumed
    case completed                            // Playback completed
    case failed(SpeechSynthesisProviderError) // Error occurred
}
```

---

### SpeechSynthesisProviderError

Errors that can occur during synthesis.

```swift
public enum SpeechSynthesisProviderError: Error, Equatable, Sendable {
    case providerNotAvailable(SpeechSynthesisProviderType)
    case initializationFailed(String)
    case invalidText
    case voiceNotAvailable(String)
    case networkUnavailable
    case authenticationFailed
    case rateLimitExceeded
    case playbackFailed(String)
    case cancelled
    case unknown(String)
}
```

---

### SpeechSynthesisProvider Protocol

Protocol for synthesis provider implementations.

```swift
@MainActor
public protocol SpeechSynthesisProvider: AnyObject {
    static var identifier: String { get }
    static var isAvailable: Bool { get }

    var isPlaying: Bool { get }
    var isPaused: Bool { get }
    var capabilities: Set<SpeechSynthesisCapability> { get }
    var events: AsyncStream<SpeechSynthesisEvent> { get }

    func speak(text: String, voice: String?) async throws
    func stop()
    func pause()
    func resume()
}
```

---

### AppleSpeechSynthesisConfiguration

Configuration for AppleSpeechSynthesisProvider.

```swift
public struct AppleSpeechSynthesisConfiguration: Sendable {
    public let rate: Float              // 0.0 to 1.0
    public let pitchMultiplier: Float   // 0.5 to 2.0
    public let volume: Float            // 0.0 to 1.0
    public let preUtteranceDelay: TimeInterval
    public let postUtteranceDelay: TimeInterval

    public static let `default`: AppleSpeechSynthesisConfiguration

    public init(
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitchMultiplier: Float = 1.0,
        volume: Float = 1.0,
        preUtteranceDelay: TimeInterval = 0.0,
        postUtteranceDelay: TimeInterval = 0.0
    )
}
```

---

## Mock Providers

### MockSpeechRecognitionProvider

Mock provider for testing recognition.

```swift
@Observable
@MainActor
public final class MockSpeechRecognitionProvider: SpeechRecognitionProvider
```

#### Test Configuration

| Property | Type | Description |
|----------|------|-------------|
| `authorizationStatusToReturn` | `SpeechAuthorizationStatus` | Status for auth |
| `startListeningError` | `SpeechRecognitionError?` | Error to throw |

#### Call Tracking

| Property | Type | Description |
|----------|------|-------------|
| `requestAuthorizationCallCount` | `Int` | Auth call count |
| `startListeningCallCount` | `Int` | Start call count |
| `stopListeningCallCount` | `Int` | Stop call count |
| `lastRequestedLocale` | `Locale?` | Last locale |

#### Simulation Methods

```swift
func simulatePartialResult(_ text: String)
func simulateFinalResult(_ text: String, confidence: Float = 1.0)
func simulateError(_ error: SpeechRecognitionError)
func reset()
```

---

### MockSpeechSynthesisProvider

Mock provider for testing synthesis.

```swift
@Observable
@MainActor
public final class MockSpeechSynthesisProvider: SpeechSynthesisProvider
```

#### Test Configuration

| Property | Type | Description |
|----------|------|-------------|
| `autoComplete` | `Bool` | Auto-complete speak() |
| `speakError` | `SpeechSynthesisProviderError?` | Error to throw |
| `mockCapabilities` | `Set<SpeechSynthesisCapability>` | Capabilities |

#### Call Tracking

| Property | Type | Description |
|----------|------|-------------|
| `speakCallCount` | `Int` | Speak call count |
| `stopCallCount` | `Int` | Stop call count |
| `pauseCallCount` | `Int` | Pause call count |
| `resumeCallCount` | `Int` | Resume call count |
| `lastSpokenText` | `String?` | Last text |
| `lastRequestedVoice` | `String?` | Last voice |

#### Simulation Methods

```swift
func simulateCompletion()
func simulateProgress(_ progress: Float)
func simulateError(_ error: SpeechSynthesisProviderError)
func reset()
```

---

## See Also

- [Getting Started](getting-started.md)
- [Speech Recognition](speech-recognition.md)
- [Speech Synthesis](speech-synthesis.md)
- [Providers](providers.md)
- [Testing](testing.md)
