# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpeechKit is a Swift Package providing voice I/O functionality (speech-to-text and text-to-speech) using a provider-based architecture. It's designed to be dependency-free, using only Apple frameworks.

## Related Packages

- **SpeechKit**: This package - Voice I/O (speech recognition and synthesis)
- **Parley**: `/Users/maxward/Developer/2_LABS/Apps/Parley` - LLM conversation orchestration (depends on SpeechKit)

## Build Commands

```bash
# Build package
xcodebuild -scheme SpeechKit -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build

# Run tests
xcodebuild -scheme SpeechKit -destination 'platform=visionOS Simulator,name=Apple Vision Pro' test

# Run linter
swiftlint
```

## Architecture

### Components

```
SpeechKit/
├── Recognition/                      # Voice to text
│   ├── SpeechRecognitionEngine      # Main entry point
│   ├── SpeechRecognitionResult      # Recognition result model
│   └── Providers/
│       ├── SpeechRecognitionProvider  # Protocol
│       ├── SFSpeechRecognizerProvider # Apple SFSpeechRecognizer
│       ├── SpeechAnalyzerProvider     # iOS 26+ SpeechAnalyzer
│       └── MockSpeechRecognitionProvider
│
└── Synthesis/                        # Text to voice
    ├── SpeechSynthesisEngine        # Main entry point
    └── Providers/
        ├── SpeechSynthesisProvider    # Protocol
        ├── AppleSpeechSynthesisProvider # Apple AVSpeechSynthesizer
        └── MockSpeechSynthesisProvider
```

### Provider Pattern

Both Recognition and Synthesis use a provider-based architecture:
- **Protocol**: Defines the interface all providers must implement
- **Engine**: Coordinates providers, handles fallback, exposes simple API
- **Providers**: Concrete implementations (Apple, Mock, future: ElevenLabs, etc.)

## Tech Stack & Conventions

- Swift 6.2, visionOS/iOS/macOS
- `@Observable` for state, `@MainActor` for thread safety
- `async/await` everywhere (no completion handlers)
- Swift Testing framework (`@Test`), not XCTest
- **No external dependencies** - only Apple frameworks

## Code Style

### Required Patterns
- `final class` for all implementations
- Explicit access control (`public`, `internal`, `private`)
- `guard` for early exit
- `// MARK: -` sections (Properties, Lifecycle, Public Methods, Private Methods)

### Naming
- Full names, no abbreviations
- Engines: `SpeechRecognitionEngine`, `SpeechSynthesisEngine`
- Providers: `AppleSpeechSynthesisProvider`, `SFSpeechRecognizerProvider`
- Protocols: `SpeechRecognitionProvider`, `SpeechSynthesisProvider`

### Test Naming
```swift
@Test("Engine initializes with default provider")
func engineInitializesWithDefaultProvider() async throws { }
```

## Recognition Providers

| Provider | Platform | Features |
|----------|----------|----------|
| `SFSpeechRecognizerProvider` | iOS 10+, visionOS | On-device or server, requires authorization |
| `SpeechAnalyzerProvider` | iOS 26+ | New API, improved accuracy |
| `MockSpeechRecognitionProvider` | All | Testing only |

## Synthesis Providers

| Provider | Platform | Features |
|----------|----------|----------|
| `AppleSpeechSynthesisProvider` | All | Offline, free, pause/resume support |
| `MockSpeechSynthesisProvider` | All | Testing only |
| Future: `ElevenLabsProvider` | All | High quality, streaming, requires API key |
| Future: `OpenAITTSProvider` | All | Multiple voices, requires API key |
