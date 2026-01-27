# Providers

SpeechKit uses a provider-based architecture that allows you to switch between different speech engines without changing your application code.

## Overview

Both speech recognition and synthesis use the same pattern:
- **Protocol**: Defines the interface all providers must implement
- **Engine**: Coordinates providers and exposes a simple API
- **Providers**: Concrete implementations of the protocol

## Recognition Providers

### SpeechRecognitionProvider Protocol

```swift
@MainActor
public protocol SpeechRecognitionProvider: AnyObject {
    /// Unique identifier for the provider
    static var identifier: String { get }

    /// Whether the provider is available on this device
    static var isAvailable: Bool { get }

    /// Current listening state
    var isListening: Bool { get }

    /// Authorization status
    var authorizationStatus: SpeechAuthorizationStatus { get }

    /// Current partial transcription
    var partialTranscription: String { get }

    /// Stream of recognition results
    var results: AsyncStream<SpeechRecognitionResult> { get }

    /// Request authorization
    func requestAuthorization() async -> SpeechAuthorizationStatus

    /// Start listening for speech
    func startListening(locale: Locale) async throws

    /// Stop listening
    func stopListening()
}
```

### Available Recognition Providers

#### SFSpeechRecognizerProvider

Apple's standard speech recognition using `SFSpeechRecognizer`.

| Feature | Value |
|---------|-------|
| Identifier | `com.apple.sfspeechrecognizer` |
| Platforms | iOS 10+, macOS 10.15+, visionOS 1.0+ |
| Offline | Yes (with downloaded models) |
| Languages | 50+ languages |
| Authorization | Required |

```swift
let engine = SpeechRecognitionEngine(providerType: .sfSpeechRecognizer)
```

**Pros:**
- Widely available
- Good accuracy
- Offline support with downloaded models
- Many languages supported

**Cons:**
- Requires authorization
- Rate limited for on-device processing

#### SpeechAnalyzerProvider

Apple's new speech analysis framework (iOS 26+).

| Feature | Value |
|---------|-------|
| Identifier | `com.apple.speechanalyzer` |
| Platforms | iOS 26+, visionOS 3.0+ |
| Offline | Yes |
| Languages | Multiple |
| Authorization | Required |

```swift
let engine = SpeechRecognitionEngine(providerType: .speechAnalyzer)
```

**Pros:**
- Improved accuracy
- Better performance
- Modern API

**Cons:**
- Only available on newest platforms
- Limited backward compatibility

#### MockSpeechRecognitionProvider

For testing purposes only.

| Feature | Value |
|---------|-------|
| Identifier | `com.speechkit.mock` |
| Platforms | All |
| Offline | Yes |
| Authorization | Simulated |

```swift
let mock = MockSpeechRecognitionProvider()
mock.authorizationStatusToReturn = .authorized
let engine = SpeechRecognitionEngine(provider: mock)

// Simulate speech
mock.simulatePartialResult("Hello")
mock.simulateFinalResult("Hello, world!")
```

### Provider Selection

The engine automatically selects a provider based on `providerType`:

```swift
enum SpeechRecognitionProviderType: String, CaseIterable, Sendable {
    case auto              // Automatic selection (best available)
    case sfSpeechRecognizer // Force SFSpeechRecognizer
    case speechAnalyzer    // Force SpeechAnalyzer (iOS 26+)
}
```

When using `.auto`:
1. Checks if SpeechAnalyzer is available (iOS 26+)
2. Falls back to SFSpeechRecognizer

## Synthesis Providers

### SpeechSynthesisProvider Protocol

```swift
@MainActor
public protocol SpeechSynthesisProvider: AnyObject {
    /// Unique identifier for the provider
    static var identifier: String { get }

    /// Whether the provider is available
    static var isAvailable: Bool { get }

    /// Current playback state
    var isPlaying: Bool { get }

    /// Whether playback is paused
    var isPaused: Bool { get }

    /// Supported capabilities
    var capabilities: Set<SpeechSynthesisCapability> { get }

    /// Stream of synthesis events
    var events: AsyncStream<SpeechSynthesisEvent> { get }

    /// Speak text with optional voice
    func speak(text: String, voice: String?) async throws

    /// Stop playback
    func stop()

    /// Pause playback
    func pause()

    /// Resume playback
    func resume()
}
```

### Available Synthesis Providers

#### AppleSpeechSynthesisProvider

Apple's built-in text-to-speech using `AVSpeechSynthesizer`.

| Feature | Value |
|---------|-------|
| Identifier | `com.apple.avspeechsynthesizer` |
| Platforms | All Apple platforms |
| Offline | Yes |
| Voices | System voices |
| Capabilities | pause, resume, offline |

```swift
let engine = SpeechSynthesisEngine(providerType: .apple)
```

**Configuration:**

```swift
let config = AppleSpeechSynthesisConfiguration(
    rate: 0.5,              // 0.0 to 1.0
    pitchMultiplier: 1.0,   // 0.5 to 2.0
    volume: 1.0,            // 0.0 to 1.0
    preUtteranceDelay: 0.0,
    postUtteranceDelay: 0.0
)

let provider = AppleSpeechSynthesisProvider(configuration: config)
let engine = SpeechSynthesisEngine(provider: provider)
```

**Pros:**
- Always available
- Works offline
- No API costs
- Pause/resume support

**Cons:**
- Basic voice quality
- Limited voice variety

#### MockSpeechSynthesisProvider

For testing purposes only.

| Feature | Value |
|---------|-------|
| Identifier | `com.speechkit.mock.synthesis` |
| Platforms | All |
| Offline | Yes |
| Capabilities | Configurable |

```swift
let mock = MockSpeechSynthesisProvider()
mock.autoComplete = false  // Control completion manually
let engine = SpeechSynthesisEngine(provider: mock)

// Start speaking
Task {
    try await engine.speak(text: "Hello")
}

// Later, complete the speech
mock.simulateCompletion()
```

### Future Providers (Planned)

#### ElevenLabsProvider (Coming Soon)

High-quality AI voices from ElevenLabs.

| Feature | Value |
|---------|-------|
| Platforms | All |
| Offline | No |
| Voices | AI-generated, custom |
| Capabilities | streaming |

#### OpenAITTSProvider (Coming Soon)

OpenAI's text-to-speech API.

| Feature | Value |
|---------|-------|
| Platforms | All |
| Offline | No |
| Voices | Multiple AI voices |
| Capabilities | streaming |

#### LocalTTSProvider (Coming Soon)

Fully offline TTS using local models.

| Feature | Value |
|---------|-------|
| Platforms | All |
| Offline | Yes |
| Voices | Local models |
| Capabilities | offline |

## Creating Custom Providers

### Custom Recognition Provider

```swift
@Observable
@MainActor
public final class MyCustomRecognitionProvider: SpeechRecognitionProvider {
    public static let identifier = "com.myapp.customrecognition"
    public static var isAvailable: Bool { true }

    public private(set) var isListening = false
    public var authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    public private(set) var partialTranscription = ""

    private var resultsContinuation: AsyncStream<SpeechRecognitionResult>.Continuation?

    public var results: AsyncStream<SpeechRecognitionResult> {
        AsyncStream { continuation in
            self.resultsContinuation = continuation
        }
    }

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        // Implement your authorization logic
        authorizationStatus = .authorized
        return .authorized
    }

    public func startListening(locale: Locale) async throws {
        // Implement your recognition logic
        isListening = true
    }

    public func stopListening() {
        isListening = false
        resultsContinuation?.finish()
    }

    // Call this when you have results
    func emitResult(_ text: String, isFinal: Bool) {
        let result = SpeechRecognitionResult(
            text: text,
            isFinal: isFinal,
            confidence: 1.0
        )
        partialTranscription = text
        resultsContinuation?.yield(result)
    }
}
```

### Custom Synthesis Provider

```swift
@Observable
@MainActor
public final class MyCustomSynthesisProvider: SpeechSynthesisProvider {
    public static let identifier = "com.myapp.customsynthesis"
    public static var isAvailable: Bool { true }

    public private(set) var isPlaying = false
    public private(set) var isPaused = false

    public var capabilities: Set<SpeechSynthesisCapability> {
        [.pause, .resume]
    }

    private var eventsContinuation: AsyncStream<SpeechSynthesisEvent>.Continuation?

    public var events: AsyncStream<SpeechSynthesisEvent> {
        AsyncStream { continuation in
            self.eventsContinuation = continuation
        }
    }

    public func speak(text: String, voice: String?) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeechSynthesisProviderError.invalidText
        }

        isPlaying = true
        eventsContinuation?.yield(.started)

        // Implement your synthesis logic here
        // ...

        isPlaying = false
        eventsContinuation?.yield(.completed)
    }

    public func stop() {
        isPlaying = false
        isPaused = false
        eventsContinuation?.yield(.failed(.cancelled))
    }

    public func pause() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = true
        eventsContinuation?.yield(.paused)
    }

    public func resume() {
        guard isPaused else { return }
        isPlaying = true
        isPaused = false
        eventsContinuation?.yield(.resumed)
    }
}
```

### Using Custom Providers

```swift
// Recognition
let customRecognition = MyCustomRecognitionProvider()
let recognitionEngine = SpeechRecognitionEngine(provider: customRecognition)

// Synthesis
let customSynthesis = MyCustomSynthesisProvider()
let synthesisEngine = SpeechSynthesisEngine(provider: customSynthesis)
```

## See Also

- [Speech Recognition](speech-recognition.md) - Recognition guide
- [Speech Synthesis](speech-synthesis.md) - Synthesis guide
- [Testing](testing.md) - Using mock providers
