# Getting Started with SpeechKit

This guide will help you install SpeechKit and set up your first voice-enabled feature.

## Installation

### Swift Package Manager

Add SpeechKit to your `Package.swift` file:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [.visionOS(.v2), .iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/macward/SpeechKit", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: ["SpeechKit"]
        )
    ]
)
```

### Xcode

1. Open your project in Xcode
2. Go to File → Add Package Dependencies
3. Enter: `https://github.com/macward/SpeechKit`
4. Select version requirements and click Add Package

## Project Configuration

### Required Permissions

SpeechKit requires user permission for microphone access and speech recognition. Add these keys to your `Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>This app uses speech recognition to transcribe your voice.</string>

    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs microphone access for speech recognition.</string>
</dict>
</plist>
```

### Entitlements (if applicable)

For some features, you may need to enable the Speech Recognition entitlement in your app's capabilities.

## Basic Usage

### Import the Package

```swift
import SpeechKit
```

### Speech Recognition Example

```swift
import SwiftUI
import SpeechKit

@MainActor
@Observable
final class DictationViewModel {
    private let engine = SpeechRecognitionEngine()

    var transcription: String = ""
    var isListening: Bool { engine.isListening }
    var isAuthorized: Bool { engine.authorizationStatus == .authorized }

    func requestPermission() async {
        _ = await engine.requestAuthorization()
    }

    func startDictation() async throws {
        try await engine.startListening(locale: .current)

        // Listen for results
        Task {
            for await result in engine.results {
                transcription = result.text
            }
        }
    }

    func stopDictation() {
        engine.stopListening()
    }
}

struct DictationView: View {
    @State private var viewModel = DictationViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.transcription)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

            Button(viewModel.isListening ? "Stop" : "Start") {
                Task {
                    if viewModel.isListening {
                        viewModel.stopDictation()
                    } else {
                        try await viewModel.startDictation()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isAuthorized)
        }
        .padding()
        .task {
            await viewModel.requestPermission()
        }
    }
}
```

### Speech Synthesis Example

```swift
import SwiftUI
import SpeechKit

@MainActor
@Observable
final class SpeakerViewModel {
    private let engine = SpeechSynthesisEngine()

    var isPlaying: Bool { engine.isPlaying }
    var isPaused: Bool { engine.isPaused }

    func speak(_ text: String) async throws {
        try await engine.speak(text: text)
    }

    func pause() {
        engine.pause()
    }

    func resume() {
        engine.resume()
    }

    func stop() {
        engine.stop()
    }
}

struct SpeakerView: View {
    @State private var viewModel = SpeakerViewModel()
    @State private var text = "Hello! This is SpeechKit speaking."

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter text to speak", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)

            HStack(spacing: 16) {
                Button("Speak") {
                    Task {
                        try await viewModel.speak(text)
                    }
                }
                .disabled(viewModel.isPlaying)

                Button(viewModel.isPaused ? "Resume" : "Pause") {
                    if viewModel.isPaused {
                        viewModel.resume()
                    } else {
                        viewModel.pause()
                    }
                }
                .disabled(!viewModel.isPlaying && !viewModel.isPaused)

                Button("Stop") {
                    viewModel.stop()
                }
                .disabled(!viewModel.isPlaying && !viewModel.isPaused)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
```

## Next Steps

- Learn more about [Speech Recognition](speech-recognition.md)
- Learn more about [Speech Synthesis](speech-synthesis.md)
- Explore available [Providers](providers.md)
- Set up [Testing](testing.md) with mock providers
