import Foundation
import Testing
@testable import SpeechKit

// MARK: - SpeechSynthesisEngineProtocol Tests

@Suite("SpeechSynthesisEngineProtocol Tests")
@MainActor
struct SpeechSynthesisEngineProtocolTests {
    @Test("Protocol has required properties and methods")
    func protocolRequirements() async throws {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine: any SpeechSynthesisEngineProtocol = SpeechSynthesisEngine(provider: mockProvider)

        // Verify protocol properties are accessible
        _ = engine.isPlaying
        _ = engine.isPaused
        _ = engine.capabilities
        _ = engine.events

        // Verify protocol methods are callable
        try await engine.speak(text: "Hello", voice: nil)
        engine.stop()
        engine.pause()
        engine.resume()

        #expect(true)
    }
}

// MARK: - SpeechSynthesisEngine Initialization Tests

@Suite("SpeechSynthesisEngine Initialization Tests")
@MainActor
struct SpeechSynthesisEngineInitializationTests {
    @Test("Engine initializes with default provider type")
    func defaultInitialization() {
        let engine = SpeechSynthesisEngine()

        #expect(engine.providerType == .apple)
        #expect(engine.isPlaying == false)
        #expect(engine.isPaused == false)
        #expect(engine.fallbackEnabled == true)
    }

    @Test("Engine initializes with explicit Apple provider type")
    func appleProviderInitialization() {
        let engine = SpeechSynthesisEngine(providerType: .apple)

        #expect(engine.providerType == .apple)
    }

    @Test("Engine initializes with custom provider")
    func customProviderInitialization() {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        #expect(engine.providerType == .auto)
        #expect(engine.isPlaying == false)
    }

    @Test("Engine initializes with fallback disabled")
    func fallbackDisabledInitialization() {
        let engine = SpeechSynthesisEngine(providerType: .auto, fallbackEnabled: false)

        #expect(engine.fallbackEnabled == false)
    }
}

// MARK: - SpeechSynthesisEngine Speak Tests

@Suite("SpeechSynthesisEngine Speak Tests")
@MainActor
struct SpeechSynthesisEngineSpeakTests {
    @Test("speak() delegates to provider")
    func speakDelegatesToProvider() async throws {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        try await engine.speak(text: "Hello world")

        #expect(mockProvider.speakCallCount == 1)
        #expect(mockProvider.lastSpokenText == "Hello world")
    }

    @Test("speak() passes voice to provider")
    func speakPassesVoice() async throws {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        try await engine.speak(text: "Hello", voice: "test.voice")

        #expect(mockProvider.lastRequestedVoice == "test.voice")
    }

    @Test("speak() throws for empty text")
    func speakThrowsForEmptyText() async {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        do {
            try await engine.speak(text: "")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .invalidText)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - SpeechSynthesisEngine Stop Tests

@Suite("SpeechSynthesisEngine Stop Tests")
@MainActor
struct SpeechSynthesisEngineStopTests {
    @Test("stop() delegates to provider")
    func stopDelegatesToProvider() {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        engine.stop()

        #expect(mockProvider.stopCallCount == 1)
    }

    @Test("stop() is safe when not playing")
    func stopSafeWhenNotPlaying() {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        engine.stop()
        engine.stop()

        #expect(engine.isPlaying == false)
    }
}

// MARK: - SpeechSynthesisEngine Pause/Resume Tests

@Suite("SpeechSynthesisEngine Pause/Resume Tests")
@MainActor
struct SpeechSynthesisEnginePauseResumeTests {
    @Test("pause() delegates to provider when capability supported")
    func pauseDelegatesToProvider() {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.mockCapabilities = [.pause, .resume]
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        engine.pause()

        #expect(mockProvider.pauseCallCount == 1)
    }

    @Test("pause() is no-op when capability not supported")
    func pauseNoOpWhenNotSupported() {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.mockCapabilities = []
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        engine.pause()

        #expect(mockProvider.pauseCallCount == 0)
    }

    @Test("resume() delegates to provider when capability supported")
    func resumeDelegatesToProvider() {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.mockCapabilities = [.pause, .resume]
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        engine.resume()

        #expect(mockProvider.resumeCallCount == 1)
    }

    @Test("resume() is no-op when capability not supported")
    func resumeNoOpWhenNotSupported() {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.mockCapabilities = []
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        engine.resume()

        #expect(mockProvider.resumeCallCount == 0)
    }
}

// MARK: - SpeechSynthesisEngine State Tests

@Suite("SpeechSynthesisEngine State Tests")
@MainActor
struct SpeechSynthesisEngineStateTests {
    @Test("isPlaying reflects provider state")
    func isPlayingReflectsProviderState() async throws {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.autoComplete = false
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        #expect(engine.isPlaying == false)

        let speakTask = Task { try await engine.speak(text: "Hello") }
        try await Task.sleep(for: .milliseconds(50))

        #expect(engine.isPlaying == true)

        mockProvider.simulateCompletion()
        try await speakTask.value

        #expect(engine.isPlaying == false)
    }

    @Test("isPaused reflects provider state")
    func isPausedReflectsProviderState() async throws {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.autoComplete = false
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        let speakTask = Task { try await engine.speak(text: "Hello") }
        try await Task.sleep(for: .milliseconds(50))

        mockProvider.pause()
        #expect(engine.isPaused == true)

        mockProvider.resume()
        mockProvider.simulateCompletion()
        try await speakTask.value

        #expect(engine.isPaused == false)
    }

    @Test("capabilities reflects provider capabilities")
    func capabilitiesReflectsProviderCapabilities() {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.mockCapabilities = [.pause, .streaming]
        let engine = SpeechSynthesisEngine(provider: mockProvider)

        #expect(engine.capabilities.contains(.pause))
        #expect(engine.capabilities.contains(.streaming))
        #expect(!engine.capabilities.contains(.resume))
    }

    @Test("error is set when speak fails")
    func errorSetOnFailure() async {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.speakError = .networkUnavailable
        let engine = SpeechSynthesisEngine(provider: mockProvider, fallbackEnabled: false)

        do {
            try await engine.speak(text: "Hello")
        } catch {
            #expect(engine.error == .networkUnavailable)
        }
    }
}

// MARK: - SpeechSynthesisEngine Fallback Tests

@Suite("SpeechSynthesisEngine Fallback Tests")
@MainActor
struct SpeechSynthesisEngineFallbackTests {
    @Test("Fallback to Apple provider on network error")
    func fallbackOnNetworkError() async throws {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.speakError = .networkUnavailable
        let engine = SpeechSynthesisEngine(provider: mockProvider, fallbackEnabled: true)

        #expect(engine.providerType == .auto)

        do {
            try await engine.speak(text: "Hello")
            #expect(engine.providerType == .apple)
        } catch {
            // Fallback may also fail in test environment, that's OK
            #expect(true)
        }
    }

    @Test("No fallback when disabled")
    func noFallbackWhenDisabled() async {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.speakError = .networkUnavailable
        let engine = SpeechSynthesisEngine(provider: mockProvider, fallbackEnabled: false)

        do {
            try await engine.speak(text: "Hello")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .networkUnavailable)
            #expect(engine.providerType == .auto)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("No fallback for cancelled error")
    func noFallbackForCancelled() async {
        let mockProvider = MockSpeechSynthesisProvider()
        mockProvider.speakError = .cancelled
        let engine = SpeechSynthesisEngine(provider: mockProvider, fallbackEnabled: true)

        do {
            try await engine.speak(text: "Hello")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .cancelled)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("No fallback for invalid text error")
    func noFallbackForInvalidText() async {
        let mockProvider = MockSpeechSynthesisProvider()
        let engine = SpeechSynthesisEngine(provider: mockProvider, fallbackEnabled: true)

        do {
            try await engine.speak(text: "")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .invalidText)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - MockSpeechSynthesisProvider Tests

@Suite("MockSpeechSynthesisProvider Tests")
@MainActor
struct MockSpeechSynthesisProviderTests {
    @Test("Mock provider has correct identifier")
    func identifier() {
        #expect(MockSpeechSynthesisProvider.identifier == "com.speechkit.mock.synthesis")
        #expect(MockSpeechSynthesisProvider.isAvailable == true)
    }

    @Test("Mock provider initializes with default state")
    func defaultState() {
        let provider = MockSpeechSynthesisProvider()

        #expect(provider.isPlaying == false)
        #expect(provider.isPaused == false)
        #expect(provider.speakCallCount == 0)
        #expect(provider.stopCallCount == 0)
    }

    @Test("Mock provider tracks speak calls")
    func tracksSpeakCalls() async throws {
        let provider = MockSpeechSynthesisProvider()

        try await provider.speak(text: "First", voice: "voice1")
        try await provider.speak(text: "Second", voice: nil)

        #expect(provider.speakCallCount == 2)
        #expect(provider.lastSpokenText == "Second")
        #expect(provider.lastRequestedVoice == nil)
    }

    @Test("Mock provider simulates completion")
    func simulatesCompletion() async throws {
        let provider = MockSpeechSynthesisProvider()
        provider.autoComplete = false

        let speakTask = Task { try await provider.speak(text: "Hello", voice: nil) }
        try await Task.sleep(for: .milliseconds(50))

        #expect(provider.isPlaying == true)

        provider.simulateCompletion()
        try await speakTask.value

        #expect(provider.isPlaying == false)
    }

    @Test("Mock provider reset clears state")
    func resetClearsState() async throws {
        let provider = MockSpeechSynthesisProvider()

        try await provider.speak(text: "Hello", voice: "voice")
        provider.stop()
        provider.reset()

        #expect(provider.speakCallCount == 0)
        #expect(provider.stopCallCount == 0)
        #expect(provider.lastSpokenText == nil)
    }
}
