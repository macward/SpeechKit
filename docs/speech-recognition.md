# Speech Recognition

SpeechKit provides a powerful and flexible speech recognition system through `SpeechRecognitionEngine`.

## Overview

The speech recognition system converts spoken words into text using a provider-based architecture. This allows you to switch between different speech recognition engines (Apple's SFSpeechRecognizer, SpeechAnalyzer, or custom implementations) without changing your application code.

## SpeechRecognitionEngine

### Creating an Engine

```swift
import SpeechKit

// Default configuration (uses SFSpeechRecognizer)
let engine = SpeechRecognitionEngine()

// With specific provider type
let engine = SpeechRecognitionEngine(providerType: .sfSpeechRecognizer)

// With custom silence threshold (seconds before auto-stop)
let engine = SpeechRecognitionEngine(silenceThreshold: 2.0)

// With custom provider (for testing or custom implementations)
let mockProvider = MockSpeechRecognitionProvider()
let engine = SpeechRecognitionEngine(provider: mockProvider)
```

### Authorization

Speech recognition requires user authorization. Always request authorization before starting recognition:

```swift
// Request authorization
let status = await engine.requestAuthorization()

switch status {
case .authorized:
    print("Ready to recognize speech")
case .denied:
    print("User denied speech recognition")
case .restricted:
    print("Speech recognition is restricted on this device")
case .notDetermined:
    print("Authorization not yet requested")
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isListening` | `Bool` | Whether the engine is currently listening |
| `authorizationStatus` | `SpeechAuthorizationStatus` | Current authorization status |
| `partialTranscription` | `String` | Current partial transcription |
| `lastResult` | `SpeechRecognitionResult?` | Most recent recognition result |
| `error` | `SpeechRecognitionError?` | Last error, if any |
| `providerType` | `SpeechRecognitionProviderType` | Type of provider being used |

### Starting Recognition

```swift
// Start listening with current locale
try await engine.startListening(locale: .current)

// Start listening with specific locale
try await engine.startListening(locale: Locale(identifier: "es-ES"))
```

### Receiving Results

Results are delivered through an `AsyncStream`:

```swift
// Iterate over results
for await result in engine.results {
    print("Text: \(result.text)")
    print("Is Final: \(result.isFinal)")
    print("Confidence: \(result.confidence)")

    if result.isFinal {
        // Handle final transcription
        handleFinalResult(result)
    }
}
```

### Stopping Recognition

```swift
engine.stopListening()
```

## SpeechRecognitionResult

The result object contains the transcription and metadata:

```swift
public struct SpeechRecognitionResult: Sendable, Equatable {
    /// The transcribed text
    public let text: String

    /// Whether this is the final result
    public let isFinal: Bool

    /// Confidence level (0.0 to 1.0)
    public let confidence: Float

    /// When the result was generated
    public let timestamp: Date
}
```

## Error Handling

```swift
do {
    try await engine.startListening(locale: .current)
} catch let error as SpeechRecognitionError {
    switch error {
    case .notAvailable:
        print("Speech recognition not available")
    case .notAuthorized:
        print("Not authorized for speech recognition")
    case .audioEngineError(let message):
        print("Audio error: \(message)")
    case .recognitionFailed(let message):
        print("Recognition failed: \(message)")
    case .cancelled:
        print("Recognition was cancelled")
    }
}
```

## Locale Support

SpeechKit supports multiple languages through locales:

```swift
// Use device's current locale
try await engine.startListening(locale: .current)

// Specific languages
try await engine.startListening(locale: Locale(identifier: "en-US"))
try await engine.startListening(locale: Locale(identifier: "es-ES"))
try await engine.startListening(locale: Locale(identifier: "fr-FR"))
try await engine.startListening(locale: Locale(identifier: "de-DE"))
try await engine.startListening(locale: Locale(identifier: "ja-JP"))
```

## Continuous vs Single-Shot Recognition

### Continuous Recognition

For ongoing transcription (like dictation):

```swift
try await engine.startListening(locale: .current)

// Process results as they come
for await result in engine.results {
    updateUI(with: result.text)

    // Optionally stop after final result
    if result.isFinal {
        break
    }
}
```

### Single-Shot Recognition

For single commands or phrases:

```swift
try await engine.startListening(locale: .current)

// Wait for first final result
for await result in engine.results where result.isFinal {
    engine.stopListening()
    return result.text
}
```

## Real-Time Partial Results

Access partial results as the user speaks:

```swift
// Via the results stream
for await result in engine.results {
    if result.isFinal {
        finalText = result.text
    } else {
        partialText = result.text  // Update UI with partial text
    }
}

// Or via the property (for @Observable binding)
Text(engine.partialTranscription)
```

## Best Practices

### 1. Always Check Authorization

```swift
func startRecognition() async throws {
    guard engine.authorizationStatus == .authorized else {
        let status = await engine.requestAuthorization()
        guard status == .authorized else {
            throw MyError.notAuthorized
        }
    }

    try await engine.startListening(locale: .current)
}
```

### 2. Handle Interruptions

```swift
// Stop listening when app goes to background
NotificationCenter.default.addObserver(
    forName: UIApplication.willResignActiveNotification,
    object: nil,
    queue: .main
) { _ in
    engine.stopListening()
}
```

### 3. Provide Visual Feedback

```swift
struct RecognitionView: View {
    let engine: SpeechRecognitionEngine

    var body: some View {
        VStack {
            // Show listening indicator
            if engine.isListening {
                WaveformView()
            }

            // Show partial transcription
            Text(engine.partialTranscription)
                .foregroundColor(.secondary)
        }
    }
}
```

### 4. Handle Errors Gracefully

```swift
func handleRecognitionError(_ error: SpeechRecognitionError) {
    switch error {
    case .notAvailable:
        showAlert("Speech recognition is not available on this device")
    case .notAuthorized:
        showSettingsPrompt()
    case .audioEngineError:
        showRetryOption()
    case .recognitionFailed:
        showRetryOption()
    case .cancelled:
        // User cancelled, no action needed
        break
    }
}
```

## See Also

- [Providers](providers.md) - Available recognition providers
- [Testing](testing.md) - Using MockSpeechRecognitionProvider
- [API Reference](api-reference.md) - Complete API documentation
