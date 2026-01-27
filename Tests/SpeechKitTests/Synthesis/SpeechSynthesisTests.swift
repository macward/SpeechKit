import Foundation
import Testing
@testable import SpeechKit

// MARK: - SpeechSynthesisProviderType Tests

@Suite("SpeechSynthesisProviderType Tests")
struct SpeechSynthesisProviderTypeTests {
    @Test("Provider type has all expected cases")
    func allCases() {
        let cases = SpeechSynthesisProviderType.allCases

        #expect(cases.contains(.auto))
        #expect(cases.contains(.apple))
        #expect(cases.contains(.elevenLabs))
        #expect(cases.contains(.openAI))
        #expect(cases.contains(.localTTS))
        #expect(cases.count == 5)
    }

    @Test("Provider type raw values are correct")
    func rawValues() {
        #expect(SpeechSynthesisProviderType.auto.rawValue == "auto")
        #expect(SpeechSynthesisProviderType.apple.rawValue == "apple")
        #expect(SpeechSynthesisProviderType.elevenLabs.rawValue == "elevenLabs")
        #expect(SpeechSynthesisProviderType.openAI.rawValue == "openAI")
        #expect(SpeechSynthesisProviderType.localTTS.rawValue == "localTTS")
    }

    @Test("Provider type is Sendable")
    func sendable() async {
        let type: SpeechSynthesisProviderType = .apple

        await Task.detached {
            let _ = type.rawValue
        }.value

        #expect(true)
    }
}

// MARK: - SpeechSynthesisCapability Tests

@Suite("SpeechSynthesisCapability Tests")
struct SpeechSynthesisCapabilityTests {
    @Test("Capability has all expected cases")
    func allCases() {
        let cases = SpeechSynthesisCapability.allCases

        #expect(cases.contains(.pause))
        #expect(cases.contains(.resume))
        #expect(cases.contains(.streaming))
        #expect(cases.contains(.offline))
        #expect(cases.count == 4)
    }

    @Test("Capability raw values are correct")
    func rawValues() {
        #expect(SpeechSynthesisCapability.pause.rawValue == "pause")
        #expect(SpeechSynthesisCapability.resume.rawValue == "resume")
        #expect(SpeechSynthesisCapability.streaming.rawValue == "streaming")
        #expect(SpeechSynthesisCapability.offline.rawValue == "offline")
    }

    @Test("Capability is Sendable")
    func sendable() async {
        let capability: SpeechSynthesisCapability = .pause

        await Task.detached {
            let _ = capability.rawValue
        }.value

        #expect(true)
    }
}

// MARK: - SpeechSynthesisEvent Tests

@Suite("SpeechSynthesisEvent Tests")
struct SpeechSynthesisEventTests {
    @Test("Event has started case")
    func startedCase() {
        let event: SpeechSynthesisEvent = .started

        if case .started = event {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected .started case")
        }
    }

    @Test("Event has progress case with value")
    func progressCase() {
        let event: SpeechSynthesisEvent = .progress(0.5)

        if case .progress(let value) = event {
            #expect(value == 0.5)
        } else {
            #expect(Bool(false), "Expected .progress case")
        }
    }

    @Test("Event has paused case")
    func pausedCase() {
        let event: SpeechSynthesisEvent = .paused

        if case .paused = event {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected .paused case")
        }
    }

    @Test("Event has resumed case")
    func resumedCase() {
        let event: SpeechSynthesisEvent = .resumed

        if case .resumed = event {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected .resumed case")
        }
    }

    @Test("Event has completed case")
    func completedCase() {
        let event: SpeechSynthesisEvent = .completed

        if case .completed = event {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected .completed case")
        }
    }

    @Test("Event has failed case with error")
    func failedCase() {
        let event: SpeechSynthesisEvent = .failed(.invalidText)

        if case .failed(let error) = event {
            #expect(error == .invalidText)
        } else {
            #expect(Bool(false), "Expected .failed case")
        }
    }

    @Test("Event is Sendable")
    func sendable() async {
        let event: SpeechSynthesisEvent = .started

        await Task.detached {
            if case .started = event {
                // OK
            }
        }.value

        #expect(true)
    }
}

// MARK: - SpeechSynthesisProviderError Tests

@Suite("SpeechSynthesisProviderError Tests")
struct SpeechSynthesisProviderErrorTests {
    @Test("Error has all expected cases")
    func allCases() {
        let providerNotAvailable: SpeechSynthesisProviderError = .providerNotAvailable(.apple)
        let initFailed: SpeechSynthesisProviderError = .initializationFailed("Test")
        let invalidText: SpeechSynthesisProviderError = .invalidText
        let voiceNotAvailable: SpeechSynthesisProviderError = .voiceNotAvailable("test.voice")
        let networkUnavailable: SpeechSynthesisProviderError = .networkUnavailable
        let authFailed: SpeechSynthesisProviderError = .authenticationFailed
        let rateLimited: SpeechSynthesisProviderError = .rateLimitExceeded
        let playbackFailed: SpeechSynthesisProviderError = .playbackFailed("Test")
        let cancelled: SpeechSynthesisProviderError = .cancelled
        let unknown: SpeechSynthesisProviderError = .unknown("Test")

        #expect(providerNotAvailable == .providerNotAvailable(.apple))
        #expect(initFailed == .initializationFailed("Test"))
        #expect(invalidText == .invalidText)
        #expect(voiceNotAvailable == .voiceNotAvailable("test.voice"))
        #expect(networkUnavailable == .networkUnavailable)
        #expect(authFailed == .authenticationFailed)
        #expect(rateLimited == .rateLimitExceeded)
        #expect(playbackFailed == .playbackFailed("Test"))
        #expect(cancelled == .cancelled)
        #expect(unknown == .unknown("Test"))
    }

    @Test("Error is Equatable")
    func equatable() {
        let error1: SpeechSynthesisProviderError = .invalidText
        let error2: SpeechSynthesisProviderError = .invalidText

        #expect(error1 == error2)
    }

    @Test("Error with same message is equal")
    func errorMessageEquality() {
        let error1: SpeechSynthesisProviderError = .playbackFailed("Same message")
        let error2: SpeechSynthesisProviderError = .playbackFailed("Same message")

        #expect(error1 == error2)
    }

    @Test("Error with different message is not equal")
    func errorMessageInequality() {
        let error1: SpeechSynthesisProviderError = .playbackFailed("Message 1")
        let error2: SpeechSynthesisProviderError = .playbackFailed("Message 2")

        #expect(error1 != error2)
    }

    @Test("Error is Sendable")
    func sendable() async {
        let error: SpeechSynthesisProviderError = .invalidText

        await Task.detached {
            let _ = error == .invalidText
        }.value

        #expect(true)
    }
}

// MARK: - AppleSpeechSynthesisConfiguration Tests

@Suite("AppleSpeechSynthesisConfiguration Tests")
struct AppleSpeechSynthesisConfigurationTests {
    @Test("Configuration initializes with default values")
    func defaultInitialization() {
        let config = AppleSpeechSynthesisConfiguration()

        #expect(config.pitchMultiplier == 1.0)
        #expect(config.volume == 1.0)
        #expect(config.preUtteranceDelay == 0.0)
        #expect(config.postUtteranceDelay == 0.0)
    }

    @Test("Configuration initializes with custom values")
    func customInitialization() {
        let config = AppleSpeechSynthesisConfiguration(
            rate: 0.3,
            pitchMultiplier: 1.5,
            volume: 0.8,
            preUtteranceDelay: 0.5,
            postUtteranceDelay: 0.2
        )

        #expect(config.rate == 0.3)
        #expect(config.pitchMultiplier == 1.5)
        #expect(config.volume == 0.8)
        #expect(config.preUtteranceDelay == 0.5)
        #expect(config.postUtteranceDelay == 0.2)
    }

    @Test("Configuration has static default")
    func staticDefault() {
        let config = AppleSpeechSynthesisConfiguration.default

        #expect(config.pitchMultiplier == 1.0)
        #expect(config.volume == 1.0)
    }

    @Test("Configuration is Sendable")
    func sendable() async {
        let config = AppleSpeechSynthesisConfiguration()

        await Task.detached {
            let _ = config.volume
        }.value

        #expect(true)
    }
}

// MARK: - AppleSpeechSynthesisProvider Tests

@Suite("AppleSpeechSynthesisProvider Tests")
@MainActor
struct AppleSpeechSynthesisProviderTests {
    @Test("Provider has correct identifier")
    func identifier() {
        #expect(AppleSpeechSynthesisProvider.identifier == "com.apple.avspeechsynthesizer")
    }

    @Test("Provider is available")
    func isAvailable() {
        #expect(AppleSpeechSynthesisProvider.isAvailable == true)
    }

    @Test("Provider initializes with default values")
    func defaultInitialization() {
        let provider = AppleSpeechSynthesisProvider()

        #expect(provider.isPlaying == false)
        #expect(provider.isPaused == false)
    }

    @Test("Provider initializes with custom configuration")
    func customConfiguration() {
        let config = AppleSpeechSynthesisConfiguration(
            rate: 0.3,
            pitchMultiplier: 1.2,
            volume: 0.9
        )
        let provider = AppleSpeechSynthesisProvider(configuration: config)

        #expect(provider.isPlaying == false)
        #expect(provider.isPaused == false)
    }

    @Test("Provider has correct capabilities")
    func capabilities() {
        let provider = AppleSpeechSynthesisProvider()
        let capabilities = provider.capabilities

        #expect(capabilities.contains(.pause))
        #expect(capabilities.contains(.resume))
        #expect(capabilities.contains(.offline))
        #expect(!capabilities.contains(.streaming))
    }

    @Test("Provider throws for empty text")
    func emptyTextThrows() async {
        let provider = AppleSpeechSynthesisProvider()

        do {
            try await provider.speak(text: "", voice: nil)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .invalidText)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Provider throws for whitespace-only text")
    func whitespaceTextThrows() async {
        let provider = AppleSpeechSynthesisProvider()

        do {
            try await provider.speak(text: "   \n\t  ", voice: nil)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .invalidText)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Provider throws for invalid voice")
    func invalidVoiceThrows() async {
        let provider = AppleSpeechSynthesisProvider()

        do {
            try await provider.speak(text: "Hello", voice: "invalid.voice.identifier.that.does.not.exist")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechSynthesisProviderError {
            #expect(error == .voiceNotAvailable("invalid.voice.identifier.that.does.not.exist"))
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("stop() is safe when not playing")
    func stopWhenNotPlaying() {
        let provider = AppleSpeechSynthesisProvider()

        provider.stop()

        #expect(provider.isPlaying == false)
    }

    @Test("pause() is safe when not playing")
    func pauseWhenNotPlaying() {
        let provider = AppleSpeechSynthesisProvider()

        provider.pause()

        #expect(provider.isPaused == false)
    }

    @Test("resume() is safe when not paused")
    func resumeWhenNotPaused() {
        let provider = AppleSpeechSynthesisProvider()

        provider.resume()

        #expect(provider.isPlaying == false)
    }

    @Test("Multiple stop calls are safe")
    func multipleStopCalls() {
        let provider = AppleSpeechSynthesisProvider()

        provider.stop()
        provider.stop()
        provider.stop()

        #expect(provider.isPlaying == false)
    }
}
