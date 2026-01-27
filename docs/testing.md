# Testing

SpeechKit includes mock providers that make it easy to test your voice-enabled features without requiring actual audio hardware or user interaction.

## Overview

Mock providers allow you to:
- Simulate authorization flows
- Trigger recognition results programmatically
- Control synthesis playback and completion
- Test error handling
- Verify your code's behavior in isolation

## MockSpeechRecognitionProvider

### Setup

```swift
import Testing
@testable import SpeechKit

@Suite("Voice Command Tests")
@MainActor
struct VoiceCommandTests {
    var mockProvider: MockSpeechRecognitionProvider!
    var engine: SpeechRecognitionEngine!

    init() {
        mockProvider = MockSpeechRecognitionProvider()
        engine = SpeechRecognitionEngine(provider: mockProvider)
    }
}
```

### Testing Authorization

```swift
@Test("Handles authorized status")
func handlesAuthorization() async {
    mockProvider.authorizationStatusToReturn = .authorized

    let status = await engine.requestAuthorization()

    #expect(status == .authorized)
    #expect(mockProvider.requestAuthorizationCallCount == 1)
}

@Test("Handles denied status")
func handlesDenied() async {
    mockProvider.authorizationStatusToReturn = .denied

    let status = await engine.requestAuthorization()

    #expect(status == .denied)
}
```

### Testing Recognition

```swift
@Test("Receives partial results")
func receivesPartialResults() async throws {
    mockProvider.authorizationStatusToReturn = .authorized
    _ = await mockProvider.requestAuthorization()

    try await engine.startListening(locale: .current)

    // Simulate partial speech
    mockProvider.simulatePartialResult("Hello")

    #expect(engine.partialTranscription == "Hello")
    #expect(engine.isListening == true)
}

@Test("Receives final results")
func receivesFinalResults() async throws {
    mockProvider.authorizationStatusToReturn = .authorized
    _ = await mockProvider.requestAuthorization()

    try await engine.startListening(locale: .current)

    // Collect results
    var receivedResults: [SpeechRecognitionResult] = []

    Task {
        for await result in engine.results {
            receivedResults.append(result)
            if result.isFinal { break }
        }
    }

    // Simulate speech
    mockProvider.simulatePartialResult("Hello")
    mockProvider.simulateFinalResult("Hello, world!", confidence: 0.95)

    try await Task.sleep(for: .milliseconds(100))

    #expect(receivedResults.count == 2)
    #expect(receivedResults.last?.text == "Hello, world!")
    #expect(receivedResults.last?.isFinal == true)
}
```

### Testing Errors

```swift
@Test("Handles not authorized error")
func handlesNotAuthorized() async {
    mockProvider.authorizationStatus = .denied

    do {
        try await engine.startListening(locale: .current)
        Issue.record("Should have thrown")
    } catch let error as SpeechRecognitionError {
        #expect(error == .notAuthorized)
    } catch {
        Issue.record("Wrong error type: \(error)")
    }
}

@Test("Handles start listening error")
func handlesStartError() async {
    mockProvider.authorizationStatusToReturn = .authorized
    _ = await mockProvider.requestAuthorization()
    mockProvider.startListeningError = .notAvailable

    do {
        try await engine.startListening(locale: .current)
        Issue.record("Should have thrown")
    } catch let error as SpeechRecognitionError {
        #expect(error == .notAvailable)
    } catch {
        Issue.record("Wrong error type")
    }
}
```

### MockSpeechRecognitionProvider API

| Property/Method | Description |
|-----------------|-------------|
| `authorizationStatusToReturn` | Status to return from `requestAuthorization()` |
| `authorizationStatus` | Current authorization status |
| `startListeningError` | Error to throw on `startListening()` |
| `requestAuthorizationCallCount` | Number of authorization requests |
| `startListeningCallCount` | Number of start calls |
| `stopListeningCallCount` | Number of stop calls |
| `lastRequestedLocale` | Locale passed to last `startListening()` |
| `simulatePartialResult(_:)` | Emit a partial transcription |
| `simulateFinalResult(_:confidence:)` | Emit a final transcription |
| `simulateError(_:)` | Emit an error |
| `reset()` | Reset all state and counters |

## MockSpeechSynthesisProvider

### Setup

```swift
import Testing
@testable import SpeechKit

@Suite("Text-to-Speech Tests")
@MainActor
struct TTSTests {
    var mockProvider: MockSpeechSynthesisProvider!
    var engine: SpeechSynthesisEngine!

    init() {
        mockProvider = MockSpeechSynthesisProvider()
        engine = SpeechSynthesisEngine(provider: mockProvider)
    }
}
```

### Testing Speech

```swift
@Test("Speaks text successfully")
func speaksText() async throws {
    try await engine.speak(text: "Hello, world!")

    #expect(mockProvider.speakCallCount == 1)
    #expect(mockProvider.lastSpokenText == "Hello, world!")
}

@Test("Passes voice to provider")
func passesVoice() async throws {
    try await engine.speak(text: "Hola", voice: "es-ES-voice")

    #expect(mockProvider.lastRequestedVoice == "es-ES-voice")
}
```

### Testing Manual Completion

```swift
@Test("Waits for completion")
func waitsForCompletion() async throws {
    mockProvider.autoComplete = false

    // Start speaking in background
    let speakTask = Task {
        try await engine.speak(text: "Hello")
    }

    // Verify playing state
    try await Task.sleep(for: .milliseconds(50))
    #expect(engine.isPlaying == true)

    // Complete manually
    mockProvider.simulateCompletion()
    try await speakTask.value

    #expect(engine.isPlaying == false)
}
```

### Testing Playback Controls

```swift
@Test("Pause works when supported")
func pauseWorks() async throws {
    mockProvider.mockCapabilities = [.pause, .resume]
    mockProvider.autoComplete = false

    Task { try await engine.speak(text: "Hello") }
    try await Task.sleep(for: .milliseconds(50))

    engine.pause()

    #expect(mockProvider.pauseCallCount == 1)
    #expect(engine.isPaused == true)
}

@Test("Pause is no-op when not supported")
func pauseNoOpWhenUnsupported() {
    mockProvider.mockCapabilities = []  // No pause capability

    engine.pause()

    #expect(mockProvider.pauseCallCount == 0)
}
```

### Testing Errors

```swift
@Test("Throws for empty text")
func throwsForEmptyText() async {
    do {
        try await engine.speak(text: "")
        Issue.record("Should have thrown")
    } catch let error as SpeechSynthesisProviderError {
        #expect(error == .invalidText)
    } catch {
        Issue.record("Wrong error type")
    }
}

@Test("Handles provider error")
func handlesProviderError() async {
    mockProvider.speakError = .networkUnavailable

    do {
        try await engine.speak(text: "Hello")
        Issue.record("Should have thrown")
    } catch let error as SpeechSynthesisProviderError {
        #expect(error == .networkUnavailable)
        #expect(engine.error == .networkUnavailable)
    } catch {
        Issue.record("Wrong error type")
    }
}
```

### Testing Events

```swift
@Test("Receives speech events")
func receivesEvents() async throws {
    mockProvider.autoComplete = false
    var events: [SpeechSynthesisEvent] = []

    let eventsTask = Task {
        for await event in engine.events {
            events.append(event)
            if case .completed = event { break }
        }
    }

    Task { try await engine.speak(text: "Hello") }
    try await Task.sleep(for: .milliseconds(50))

    mockProvider.simulateProgress(0.5)
    mockProvider.simulateCompletion()

    try await eventsTask.value

    #expect(events.contains { if case .started = $0 { return true }; return false })
    #expect(events.contains { if case .completed = $0 { return true }; return false })
}
```

### MockSpeechSynthesisProvider API

| Property/Method | Description |
|-----------------|-------------|
| `autoComplete` | If true, speak() completes immediately |
| `speakError` | Error to throw on `speak()` |
| `mockCapabilities` | Capabilities to report |
| `speakCallCount` | Number of speak calls |
| `stopCallCount` | Number of stop calls |
| `pauseCallCount` | Number of pause calls |
| `resumeCallCount` | Number of resume calls |
| `lastSpokenText` | Text passed to last `speak()` |
| `lastRequestedVoice` | Voice passed to last `speak()` |
| `simulateCompletion()` | Complete the current speech |
| `simulateProgress(_:)` | Emit a progress event |
| `simulateError(_:)` | Emit an error event |
| `reset()` | Reset all state and counters |

## Integration Testing

### Testing a Complete Flow

```swift
@Suite("Voice Assistant Integration")
@MainActor
struct VoiceAssistantTests {
    @Test("Complete voice interaction")
    func completeInteraction() async throws {
        // Setup mocks
        let recognitionMock = MockSpeechRecognitionProvider()
        recognitionMock.authorizationStatusToReturn = .authorized

        let synthesisMock = MockSpeechSynthesisProvider()

        let recognitionEngine = SpeechRecognitionEngine(provider: recognitionMock)
        let synthesisEngine = SpeechSynthesisEngine(provider: synthesisMock)

        // Authorize
        _ = await recognitionEngine.requestAuthorization()

        // Start listening
        try await recognitionEngine.startListening(locale: .current)

        // User speaks
        recognitionMock.simulateFinalResult("What time is it?")

        // Get the transcription
        let transcription = recognitionEngine.partialTranscription
        #expect(transcription == "What time is it?")

        // Respond with synthesis
        try await synthesisEngine.speak(text: "It's 3 PM")

        #expect(synthesisMock.lastSpokenText == "It's 3 PM")
    }
}
```

### Testing with View Models

```swift
@MainActor
@Observable
final class VoiceViewModel {
    private let recognitionEngine: SpeechRecognitionEngine
    private let synthesisEngine: SpeechSynthesisEngine

    var transcription = ""
    var isListening: Bool { recognitionEngine.isListening }

    init(
        recognitionEngine: SpeechRecognitionEngine,
        synthesisEngine: SpeechSynthesisEngine
    ) {
        self.recognitionEngine = recognitionEngine
        self.synthesisEngine = synthesisEngine
    }

    func startListening() async throws {
        try await recognitionEngine.startListening(locale: .current)

        for await result in recognitionEngine.results where result.isFinal {
            transcription = result.text
            break
        }
    }

    func speak(_ text: String) async throws {
        try await synthesisEngine.speak(text: text)
    }
}

// Test
@Test("ViewModel handles recognition")
func viewModelRecognition() async throws {
    let recognitionMock = MockSpeechRecognitionProvider()
    recognitionMock.authorizationStatusToReturn = .authorized
    _ = await recognitionMock.requestAuthorization()

    let synthesisMock = MockSpeechSynthesisProvider()

    let viewModel = VoiceViewModel(
        recognitionEngine: SpeechRecognitionEngine(provider: recognitionMock),
        synthesisEngine: SpeechSynthesisEngine(provider: synthesisMock)
    )

    // Start listening in background
    Task {
        try await viewModel.startListening()
    }

    try await Task.sleep(for: .milliseconds(50))
    #expect(viewModel.isListening == true)

    recognitionMock.simulateFinalResult("Hello")

    try await Task.sleep(for: .milliseconds(50))
    #expect(viewModel.transcription == "Hello")
}
```

## Best Practices

### 1. Reset Mocks Between Tests

```swift
@Suite
@MainActor
struct MyTests {
    var mock: MockSpeechRecognitionProvider!

    init() {
        mock = MockSpeechRecognitionProvider()
        mock.reset()  // Ensure clean state
    }
}
```

### 2. Use Small Sleep Durations

```swift
// Give async operations time to complete
try await Task.sleep(for: .milliseconds(50))
```

### 3. Test Error Paths

```swift
@Test("Handles all error types")
func handlesErrors() async {
    for error in [
        SpeechRecognitionError.notAvailable,
        .notAuthorized,
        .audioEngineError("test"),
        .recognitionFailed("test"),
        .cancelled
    ] {
        mock.startListeningError = error
        // Test each error...
    }
}
```

### 4. Verify Call Counts

```swift
@Test("Calls provider methods correctly")
func verifiesCalls() async throws {
    try await engine.startListening(locale: .current)
    engine.stopListening()

    #expect(mock.startListeningCallCount == 1)
    #expect(mock.stopListeningCallCount == 1)
}
```

## See Also

- [Speech Recognition](speech-recognition.md) - Recognition guide
- [Speech Synthesis](speech-synthesis.md) - Synthesis guide
- [Providers](providers.md) - Provider documentation
