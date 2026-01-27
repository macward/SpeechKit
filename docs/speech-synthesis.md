# Speech Synthesis

SpeechKit provides text-to-speech functionality through `SpeechSynthesisEngine` with automatic fallback support.

## Overview

The speech synthesis system converts text into spoken audio using a provider-based architecture. It supports multiple providers, automatic fallback when a provider fails, and playback controls like pause/resume.

## SpeechSynthesisEngine

### Creating an Engine

```swift
import SpeechKit

// Default configuration (uses AppleSpeechSynthesisProvider)
let engine = SpeechSynthesisEngine()

// With specific provider type
let engine = SpeechSynthesisEngine(providerType: .apple)

// Disable automatic fallback
let engine = SpeechSynthesisEngine(providerType: .apple, fallbackEnabled: false)

// With custom provider (for testing)
let mockProvider = MockSpeechSynthesisProvider()
let engine = SpeechSynthesisEngine(provider: mockProvider)
```

### Speaking Text

```swift
// Simple usage
try await engine.speak(text: "Hello, world!")

// With specific voice
try await engine.speak(text: "Hola, mundo!", voice: "com.apple.voice.compact.es-ES.Monica")
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isPlaying` | `Bool` | Whether audio is currently playing |
| `isPaused` | `Bool` | Whether playback is paused |
| `capabilities` | `Set<SpeechSynthesisCapability>` | Supported capabilities |
| `providerType` | `SpeechSynthesisProviderType` | Type of provider being used |
| `error` | `SpeechSynthesisProviderError?` | Last error, if any |
| `fallbackEnabled` | `Bool` | Whether automatic fallback is enabled |

### Playback Controls

```swift
// Pause playback (if supported)
engine.pause()

// Resume playback (if supported)
engine.resume()

// Stop immediately
engine.stop()
```

### Checking Capabilities

Not all providers support all features. Check capabilities before using:

```swift
// Check if pause is supported
if engine.capabilities.contains(.pause) {
    engine.pause()
} else {
    // Fall back to stop
    engine.stop()
}

// Available capabilities
enum SpeechSynthesisCapability {
    case pause      // Can pause playback
    case resume     // Can resume after pause
    case streaming  // Supports streaming audio
    case offline    // Works without internet
}
```

## Events

Monitor speech synthesis events through the `events` stream:

```swift
Task {
    for await event in engine.events {
        switch event {
        case .started:
            print("Started speaking")
            showSpeakingIndicator()

        case .progress(let value):
            print("Progress: \(value * 100)%")
            updateProgressBar(value)

        case .paused:
            print("Paused")
            showPausedState()

        case .resumed:
            print("Resumed")
            showPlayingState()

        case .completed:
            print("Completed")
            hideSpeakingIndicator()

        case .failed(let error):
            print("Failed: \(error)")
            handleError(error)
        }
    }
}
```

## Error Handling

```swift
do {
    try await engine.speak(text: "Hello")
} catch let error as SpeechSynthesisProviderError {
    switch error {
    case .providerNotAvailable(let type):
        print("Provider \(type) not available")

    case .initializationFailed(let message):
        print("Init failed: \(message)")

    case .invalidText:
        print("Text was empty or invalid")

    case .voiceNotAvailable(let voiceId):
        print("Voice not found: \(voiceId)")

    case .networkUnavailable:
        print("Network required but unavailable")

    case .authenticationFailed:
        print("API authentication failed")

    case .rateLimitExceeded:
        print("API rate limit exceeded")

    case .playbackFailed(let message):
        print("Playback error: \(message)")

    case .cancelled:
        print("Playback was cancelled")

    case .unknown(let message):
        print("Unknown error: \(message)")
    }
}
```

## Automatic Fallback

When `fallbackEnabled` is true (default), the engine automatically falls back to `AppleSpeechSynthesisProvider` if the primary provider fails:

```swift
// With a provider that might fail (e.g., network-based)
let engine = SpeechSynthesisEngine(providerType: .elevenLabs)

// If ElevenLabs fails, automatically tries AppleSpeechSynthesisProvider
try await engine.speak(text: "Hello")

// Check which provider was actually used
print("Used provider: \(engine.providerType)")
```

Fallback is **not** triggered for:
- `.cancelled` errors (user-initiated)
- `.invalidText` errors (input validation)
- When already using AppleSpeechSynthesisProvider

## Voice Selection

### List Available Voices

```swift
import AVFoundation

// Get all available voices
let voices = AVSpeechSynthesisVoice.speechVoices()

// Filter by language
let spanishVoices = voices.filter { $0.language.starts(with: "es") }

for voice in spanishVoices {
    print("Name: \(voice.name)")
    print("ID: \(voice.identifier)")
    print("Quality: \(voice.quality.rawValue)")
}
```

### Using a Specific Voice

```swift
// By identifier
try await engine.speak(
    text: "Buenos días",
    voice: "com.apple.voice.compact.es-ES.Monica"
)

// Get identifier from AVSpeechSynthesisVoice
let voice = AVSpeechSynthesisVoice(language: "es-ES")
if let voiceId = voice?.identifier {
    try await engine.speak(text: "Hola", voice: voiceId)
}
```

### Voice Quality Tiers

| Quality | Description |
|---------|-------------|
| `.default` | Basic quality, small download |
| `.enhanced` | Better quality, larger download |
| `.premium` | Best quality, requires download |

## AppleSpeechSynthesisProvider Configuration

For fine-grained control, create a custom configuration:

```swift
let config = AppleSpeechSynthesisConfiguration(
    rate: 0.5,              // Speed (0.0 to 1.0)
    pitchMultiplier: 1.2,   // Pitch (0.5 to 2.0)
    volume: 0.8,            // Volume (0.0 to 1.0)
    preUtteranceDelay: 0.0, // Delay before speaking
    postUtteranceDelay: 0.0 // Delay after speaking
)

let provider = AppleSpeechSynthesisProvider(configuration: config)
let engine = SpeechSynthesisEngine(provider: provider)
```

### Rate Presets

```swift
// Predefined rates
let slowRate = AVSpeechUtteranceDefaultSpeechRate * 0.5
let normalRate = AVSpeechUtteranceDefaultSpeechRate
let fastRate = AVSpeechUtteranceDefaultSpeechRate * 1.5
```

## Use Cases

### Reading Long Text

```swift
func readArticle(_ text: String) async {
    // Split into paragraphs for better pacing
    let paragraphs = text.components(separatedBy: "\n\n")

    for paragraph in paragraphs {
        guard !paragraph.isEmpty else { continue }

        try? await engine.speak(text: paragraph)

        // Brief pause between paragraphs
        try? await Task.sleep(for: .milliseconds(500))
    }
}
```

### Accessibility Announcements

```swift
func announce(_ message: String) {
    Task {
        // Stop any current speech
        engine.stop()

        // Speak the announcement
        try? await engine.speak(text: message)
    }
}
```

### Voice Assistant Response

```swift
func speakResponse(_ response: String) async throws {
    // Observe completion
    let eventsTask = Task {
        for await event in engine.events {
            if case .completed = event {
                onResponseComplete()
                break
            }
        }
    }

    try await engine.speak(text: response)
    eventsTask.cancel()
}
```

## Best Practices

### 1. Stop Before Speaking New Text

```swift
func speak(_ text: String) async throws {
    // Ensure clean state
    engine.stop()

    try await engine.speak(text: text)
}
```

### 2. Validate Text Before Speaking

```swift
func speak(_ text: String) async throws {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return // Don't attempt to speak empty text
    }

    try await engine.speak(text: trimmed)
}
```

### 3. Handle Interruptions

```swift
// Stop when app goes to background
NotificationCenter.default.addObserver(
    forName: UIApplication.willResignActiveNotification,
    object: nil,
    queue: .main
) { _ in
    engine.stop()
}
```

### 4. Respect User Preferences

```swift
// Check if user has reduced motion/audio preferences
if UIAccessibility.isReduceMotionEnabled {
    // Consider using slower speech rate
}
```

## See Also

- [Providers](providers.md) - Available synthesis providers
- [Testing](testing.md) - Using MockSpeechSynthesisProvider
- [API Reference](api-reference.md) - Complete API documentation
