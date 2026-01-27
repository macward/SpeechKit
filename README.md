# SpeechKit

A Swift package providing voice I/O functionality (speech-to-text and text-to-speech) for Apple platforms using a provider-based architecture.

## Features

- **Speech Recognition** - Convert voice to text with multiple provider options
- **Speech Synthesis** - Convert text to voice with automatic fallback
- **Provider Architecture** - Easily switch between different speech engines
- **Modern Swift** - Built with Swift 6, async/await, @Observable, and @MainActor
- **Zero Dependencies** - Uses only Apple frameworks
- **Comprehensive Testing** - Full test suite with mock providers

## Platforms

| Platform | Minimum Version |
|----------|-----------------|
| visionOS | 2.0 |
| iOS | 17.0 |
| macOS | 14.0 |

## Installation

### Swift Package Manager

Add SpeechKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/macward/SpeechKit", from: "1.0.0")
]
```

Or add it via Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

### Speech Recognition

```swift
import SpeechKit

// Create engine
let engine = SpeechRecognitionEngine()

// Request authorization
let status = await engine.requestAuthorization()
guard status == .authorized else { return }

// Start listening
try await engine.startListening(locale: .current)

// Observe results
for await result in engine.results {
    print("Transcription: \(result.text)")
    if result.isFinal {
        print("Final result received")
    }
}

// Stop when done
engine.stopListening()
```

### Speech Synthesis

```swift
import SpeechKit

// Create engine
let engine = SpeechSynthesisEngine()

// Speak text
try await engine.speak(text: "Hello, world!")

// With specific voice
try await engine.speak(text: "Hola, mundo!", voice: "com.apple.voice.compact.es-ES.Monica")

// Control playback
engine.pause()
engine.resume()
engine.stop()
```

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/getting-started.md) | Installation and basic setup |
| [Speech Recognition](docs/speech-recognition.md) | Voice-to-text guide |
| [Speech Synthesis](docs/speech-synthesis.md) | Text-to-voice guide |
| [Providers](docs/providers.md) | Available providers and custom providers |
| [Testing](docs/testing.md) | Using mock providers for testing |
| [API Reference](docs/api-reference.md) | Complete API documentation |

## Architecture

```
SpeechKit/
├── Recognition/
│   ├── SpeechRecognitionEngine      # Main entry point
│   ├── SpeechRecognitionResult      # Recognition result model
│   └── Providers/
│       ├── SpeechRecognitionProvider   # Protocol
│       ├── SFSpeechRecognizerProvider  # Apple SFSpeechRecognizer
│       ├── SpeechAnalyzerProvider      # iOS 26+ SpeechAnalyzer
│       └── MockSpeechRecognitionProvider
│
└── Synthesis/
    ├── SpeechSynthesisEngine        # Main entry point
    └── Providers/
        ├── SpeechSynthesisProvider     # Protocol
        ├── AppleSpeechSynthesisProvider # Apple AVSpeechSynthesizer
        └── MockSpeechSynthesisProvider
```

## Requirements

- Swift 6.0+
- Xcode 16.0+

### Entitlements (iOS/visionOS)

Add to your `Info.plist`:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to transcribe your voice.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for speech recognition.</string>
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting a pull request.
