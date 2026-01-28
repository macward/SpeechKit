import Foundation
import Testing
@testable import SpeechKit

@Suite("SpeechRecognitionResult Tests")
struct SpeechRecognitionResultTests {
    // MARK: - Initialization

    @Test("SpeechRecognitionResult initializes with all properties")
    func initialization() {
        let result: SpeechRecognitionResult = SpeechRecognitionResult(
            text: "Hello world",
            isFinal: true,
            confidence: 0.95
        )

        #expect(result.text == "Hello world")
        #expect(result.isFinal == true)
        #expect(result.confidence == 0.95)
    }

    @Test("SpeechRecognitionResult has default confidence of 1.0")
    func defaultConfidence() {
        let result: SpeechRecognitionResult = SpeechRecognitionResult(
            text: "Test",
            isFinal: false
        )

        #expect(result.confidence == 1.0)
    }

    @Test("SpeechRecognitionResult has timestamp")
    func hasTimestamp() {
        let before: Date = Date()
        let result: SpeechRecognitionResult = SpeechRecognitionResult(
            text: "Test",
            isFinal: true
        )
        let after: Date = Date()

        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test("SpeechRecognitionResult is Equatable")
    func equatable() {
        let timestamp: Date = Date()
        let result1: SpeechRecognitionResult = SpeechRecognitionResult(
            text: "Hello",
            isFinal: true,
            confidence: 0.9,
            timestamp: timestamp
        )
        let result2: SpeechRecognitionResult = SpeechRecognitionResult(
            text: "Hello",
            isFinal: true,
            confidence: 0.9,
            timestamp: timestamp
        )

        #expect(result1 == result2)
    }

    @Test("SpeechRecognitionResult is Sendable")
    func sendable() async {
        let result: SpeechRecognitionResult = SpeechRecognitionResult(
            text: "Test",
            isFinal: true
        )

        // This compiles if Sendable conformance is correct
        await Task.detached {
            let _ = result.text
        }.value

        #expect(true)
    }
}

@Suite("SpeechAuthorizationStatus Tests")
struct SpeechAuthorizationStatusTests {
    @Test("SpeechAuthorizationStatus has all expected cases")
    func allCases() {
        let notDetermined: SpeechAuthorizationStatus = .notDetermined
        let denied: SpeechAuthorizationStatus = .denied
        let restricted: SpeechAuthorizationStatus = .restricted
        let authorized: SpeechAuthorizationStatus = .authorized

        #expect(notDetermined == .notDetermined)
        #expect(denied == .denied)
        #expect(restricted == .restricted)
        #expect(authorized == .authorized)
    }

    @Test("SpeechAuthorizationStatus is Equatable")
    func equatable() {
        let status1: SpeechAuthorizationStatus = .authorized
        let status2: SpeechAuthorizationStatus = .authorized

        #expect(status1 == status2)
    }
}

@Suite("SpeechRecognitionError Tests")
struct SpeechRecognitionErrorTests {
    @Test("SpeechRecognitionError has all expected cases")
    func allCases() {
        let notAvailable: SpeechRecognitionError = .notAvailable
        let notAuthorized: SpeechRecognitionError = .notAuthorized
        let audioError: SpeechRecognitionError = .audioEngineError("Test error")
        let recognitionError: SpeechRecognitionError = .recognitionFailed("Failed")
        let cancelled: SpeechRecognitionError = .cancelled

        #expect(notAvailable == .notAvailable)
        #expect(notAuthorized == .notAuthorized)
        #expect(audioError == .audioEngineError("Test error"))
        #expect(recognitionError == .recognitionFailed("Failed"))
        #expect(cancelled == .cancelled)
    }

    @Test("SpeechRecognitionError is Equatable")
    func equatable() {
        let error1: SpeechRecognitionError = .notAvailable
        let error2: SpeechRecognitionError = .notAvailable

        #expect(error1 == error2)
    }

    @Test("SpeechRecognitionError with same message is equal")
    func errorMessageEquality() {
        let error1: SpeechRecognitionError = .audioEngineError("Same message")
        let error2: SpeechRecognitionError = .audioEngineError("Same message")

        #expect(error1 == error2)
    }

    @Test("SpeechRecognitionError with different message is not equal")
    func errorMessageInequality() {
        let error1: SpeechRecognitionError = .audioEngineError("Message 1")
        let error2: SpeechRecognitionError = .audioEngineError("Message 2")

        #expect(error1 != error2)
    }
}

@Suite("SpeechRecognitionEngine Tests")
@MainActor
struct SpeechRecognitionEngineTests {
    @Test("SpeechRecognitionEngine initializes with default values")
    func initialization() {
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine()

        #expect(engine.isListening == false)
        #expect(engine.partialTranscription == "")
        #expect(engine.lastResult == nil)
        #expect(engine.error == nil)
    }

    @Test("SpeechRecognitionEngine initializes with custom silence threshold")
    func customSilenceThreshold() {
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(silenceThreshold: 2.0)

        // Engine should initialize without error
        #expect(engine.isListening == false)
    }

    @Test("SpeechRecognitionEngine initializes with provider type")
    func initWithProviderType() {
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(
            providerType: .sfSpeechRecognizer
        )

        #expect(engine.providerType == .sfSpeechRecognizer)
    }

    @Test("SpeechRecognitionEngine initializes with auto provider type")
    func initWithAutoProviderType() {
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(
            providerType: .auto
        )

        // Auto should resolve to sfSpeechRecognizer for now
        #expect(engine.providerType == .sfSpeechRecognizer)
    }

    @Test("SpeechRecognitionEngine initializes with custom provider")
    func initWithCustomProvider() {
        let mockProvider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(provider: mockProvider)

        #expect(engine.isListening == false)
    }

    @Test("stopListening sets isListening to false")
    func stopListening() {
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine()

        engine.stopListening()

        #expect(engine.isListening == false)
    }

    @Test("Multiple stopListening calls are safe")
    func multipleStopCalls() {
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine()

        engine.stopListening()
        engine.stopListening()
        engine.stopListening()

        #expect(engine.isListening == false)
    }
}

// MARK: - Provider Tests

@Suite("SpeechRecognitionProviderType Tests")
struct SpeechRecognitionProviderTypeTests {
    @Test("Provider type has all expected cases")
    func allCases() {
        let cases = SpeechRecognitionProviderType.allCases

        #expect(cases.contains(.auto))
        #expect(cases.contains(.sfSpeechRecognizer))
        #expect(cases.contains(.speechAnalyzer))
        #expect(cases.count == 3)
    }

    @Test("Provider type raw values are correct")
    func rawValues() {
        #expect(SpeechRecognitionProviderType.auto.rawValue == "auto")
        #expect(SpeechRecognitionProviderType.sfSpeechRecognizer.rawValue == "sfSpeechRecognizer")
        #expect(SpeechRecognitionProviderType.speechAnalyzer.rawValue == "speechAnalyzer")
    }
}

@Suite("MockSpeechRecognitionProvider Tests")
@MainActor
struct MockSpeechRecognitionProviderTests {
    @Test("MockProvider has correct identifier")
    func identifier() {
        #expect(MockSpeechRecognitionProvider.identifier == "com.speechkit.mock")
    }

    @Test("MockProvider is always available")
    func isAvailable() {
        #expect(MockSpeechRecognitionProvider.isAvailable == true)
    }

    @Test("MockProvider initializes with default values")
    func initialization() {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()

        #expect(provider.isListening == false)
        #expect(provider.authorizationStatus == .notDetermined)
        #expect(provider.partialTranscription == "")
    }

    @Test("MockProvider can simulate authorization")
    func authorization() async {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized

        let status: SpeechAuthorizationStatus = await provider.requestAuthorization()

        #expect(status == .authorized)
        #expect(provider.authorizationStatus == .authorized)
        #expect(provider.requestAuthorizationCallCount == 1)
    }

    @Test("MockProvider can simulate denied authorization")
    func deniedAuthorization() async {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .denied

        let status: SpeechAuthorizationStatus = await provider.requestAuthorization()

        #expect(status == .denied)
    }

    @Test("MockProvider can start listening when authorized")
    func startListening() async throws {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized
        _ = await provider.requestAuthorization()

        try await provider.startListening(locale: .current)

        #expect(provider.isListening == true)
        #expect(provider.startListeningCallCount == 1)
    }

    @Test("MockProvider tracks requested locale")
    func tracksLocale() async throws {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized
        _ = await provider.requestAuthorization()
        let locale = Locale(identifier: "es-ES")

        try await provider.startListening(locale: locale)

        #expect(provider.lastRequestedLocale == locale)
    }

    @Test("MockProvider throws when not authorized")
    func throwsWhenNotAuthorized() async {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatus = .denied

        do {
            try await provider.startListening(locale: .current)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechRecognitionError {
            #expect(error == .notAuthorized)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }

    @Test("MockProvider can simulate startListening error")
    func startListeningError() async {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized
        _ = await provider.requestAuthorization()
        provider.startListeningError = .notAvailable

        do {
            try await provider.startListening(locale: .current)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechRecognitionError {
            #expect(error == .notAvailable)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }

    @Test("MockProvider can stop listening")
    func stopListening() async throws {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized
        _ = await provider.requestAuthorization()
        try await provider.startListening(locale: .current)

        provider.stopListening()

        #expect(provider.isListening == false)
        #expect(provider.stopListeningCallCount == 1)
    }

    @Test("MockProvider can simulate partial result")
    func simulatePartialResult() async throws {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized
        _ = await provider.requestAuthorization()
        try await provider.startListening(locale: .current)

        provider.simulatePartialResult("Hello")

        #expect(provider.partialTranscription == "Hello")
        #expect(provider.isListening == true)
    }

    @Test("MockProvider can reset state")
    func reset() async throws {
        let provider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        provider.authorizationStatusToReturn = .authorized
        _ = await provider.requestAuthorization()
        try await provider.startListening(locale: .current)
        provider.simulatePartialResult("Test")

        provider.reset()

        #expect(provider.isListening == false)
        #expect(provider.authorizationStatus == .notDetermined)
        #expect(provider.partialTranscription == "")
        #expect(provider.requestAuthorizationCallCount == 0)
        #expect(provider.startListeningCallCount == 0)
    }
}

@Suite("SpeechRecognitionEngine with MockProvider Tests")
@MainActor
struct SpeechRecognitionEngineWithMockProviderTests {
    @Test("Engine delegates authorization to provider")
    func delegatesAuthorization() async {
        let mockProvider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        mockProvider.authorizationStatusToReturn = .authorized
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(provider: mockProvider)

        let status = await engine.requestAuthorization()

        #expect(status == .authorized)
        #expect(mockProvider.requestAuthorizationCallCount == 1)
    }

    @Test("Engine delegates startListening to provider")
    func delegatesStartListening() async throws {
        let mockProvider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        mockProvider.authorizationStatusToReturn = .authorized
        _ = await mockProvider.requestAuthorization()
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(provider: mockProvider)

        try await engine.startListening(locale: .current)

        #expect(mockProvider.startListeningCallCount == 1)
        #expect(engine.isListening == true)
    }

    @Test("Engine delegates stopListening to provider")
    func delegatesStopListening() async throws {
        let mockProvider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        mockProvider.authorizationStatusToReturn = .authorized
        _ = await mockProvider.requestAuthorization()
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(provider: mockProvider)
        try await engine.startListening(locale: .current)

        engine.stopListening()

        #expect(mockProvider.stopListeningCallCount == 1)
        #expect(engine.isListening == false)
    }

    @Test("Engine reflects provider's partialTranscription")
    func reflectsPartialTranscription() async throws {
        let mockProvider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        mockProvider.authorizationStatusToReturn = .authorized
        _ = await mockProvider.requestAuthorization()
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(provider: mockProvider)
        try await engine.startListening(locale: .current)

        mockProvider.simulatePartialResult("Hello world")

        #expect(engine.partialTranscription == "Hello world")
    }

    @Test("Engine reflects provider's authorizationStatus")
    func reflectsAuthorizationStatus() async {
        let mockProvider: MockSpeechRecognitionProvider = MockSpeechRecognitionProvider()
        mockProvider.authorizationStatusToReturn = .denied
        let engine: SpeechRecognitionEngine = SpeechRecognitionEngine(provider: mockProvider)

        _ = await engine.requestAuthorization()

        #expect(engine.authorizationStatus == .denied)
    }
}

// MARK: - Legacy Mock (for backward compatibility)

/// Mock implementation of SpeechRecognitionEngineProtocol for testing.
@MainActor
final class MockSpeechRecognitionEngine: SpeechRecognitionEngineProtocol {
    var isListening: Bool = false
    var authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    var partialTranscription: String = ""
    var lastResult: SpeechRecognitionResult?
    var error: SpeechRecognitionError?

    let results: AsyncStream<SpeechRecognitionResult>
    private let resultsContinuation: AsyncStream<SpeechRecognitionResult>.Continuation

    var requestAuthorizationResult: SpeechAuthorizationStatus = .authorized
    var startListeningError: SpeechRecognitionError?
    var simulatedTranscriptions: [String] = []

    init() {
        var continuation: AsyncStream<SpeechRecognitionResult>.Continuation!
        self.results = AsyncStream { continuation = $0 }
        self.resultsContinuation = continuation
    }

    func requestAuthorization() async -> SpeechAuthorizationStatus {
        authorizationStatus = requestAuthorizationResult
        return requestAuthorizationResult
    }

    func startListening(locale: Locale) async throws {
        if let error = startListeningError {
            throw error
        }
        isListening = true
    }

    func stopListening() {
        isListening = false
    }

    func simulateTranscription(_ text: String, isFinal: Bool) {
        partialTranscription = text
        let result = SpeechRecognitionResult(text: text, isFinal: isFinal)
        resultsContinuation.yield(result)
        if isFinal {
            lastResult = result
            isListening = false
        }
    }
}

@Suite("MockSpeechRecognitionEngine Tests")
@MainActor
struct MockSpeechRecognitionEngineTests {
    @Test("Mock can simulate authorization")
    func mockAuthorization() async {
        let mock: MockSpeechRecognitionEngine = MockSpeechRecognitionEngine()
        mock.requestAuthorizationResult = .authorized

        let status: SpeechAuthorizationStatus = await mock.requestAuthorization()

        #expect(status == .authorized)
        #expect(mock.authorizationStatus == .authorized)
    }

    @Test("Mock can simulate denied authorization")
    func mockDeniedAuthorization() async {
        let mock: MockSpeechRecognitionEngine = MockSpeechRecognitionEngine()
        mock.requestAuthorizationResult = .denied

        let status: SpeechAuthorizationStatus = await mock.requestAuthorization()

        #expect(status == .denied)
    }

    @Test("Mock can simulate startListening")
    func mockStartListening() async throws {
        let mock: MockSpeechRecognitionEngine = MockSpeechRecognitionEngine()

        try await mock.startListening(locale: .current)

        #expect(mock.isListening == true)
    }

    @Test("Mock can simulate startListening error")
    func mockStartListeningError() async {
        let mock: MockSpeechRecognitionEngine = MockSpeechRecognitionEngine()
        mock.startListeningError = .notAuthorized

        do {
            try await mock.startListening(locale: .current)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechRecognitionError {
            #expect(error == .notAuthorized)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }

    @Test("Mock can simulate transcription")
    func mockTranscription() async throws {
        let mock: MockSpeechRecognitionEngine = MockSpeechRecognitionEngine()

        try await mock.startListening(locale: .current)
        mock.simulateTranscription("Hello", isFinal: false)

        #expect(mock.partialTranscription == "Hello")
        #expect(mock.isListening == true)
    }

    @Test("Mock can simulate final transcription")
    func mockFinalTranscription() async throws {
        let mock: MockSpeechRecognitionEngine = MockSpeechRecognitionEngine()

        try await mock.startListening(locale: .current)
        mock.simulateTranscription("Hello world", isFinal: true)

        #expect(mock.lastResult?.text == "Hello world")
        #expect(mock.lastResult?.isFinal == true)
        #expect(mock.isListening == false)
    }
}
