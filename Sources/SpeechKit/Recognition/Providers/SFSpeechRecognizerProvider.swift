#if canImport(Speech)
import AVFoundation
import Foundation
import Speech

// MARK: - Non-actor helper

/// Installs an audio tap without inheriting `@MainActor` isolation.
/// Defined at file scope to ensure the tap's closure is not MainActor-isolated,
/// avoiding executor assertions when CoreAudio invokes it off the main thread.
private func installSpeechTap(
    on node: AVAudioInputNode,
    format: AVAudioFormat,
    request: SFSpeechAudioBufferRecognitionRequest
) {
    node.installTap(onBus: 0, bufferSize: SpeechRecognitionConstants.audioBufferSize, format: format) { buffer, _ in
        request.append(buffer)
    }
}

// MARK: - Constants

private enum SpeechRecognitionConstants {
    /// Error domain for speech recognition assistant errors
    static let assistantErrorDomain = "kAFAssistantErrorDomain"
    /// Error code indicating recognition was cancelled
    static let cancelledErrorCode = 216
    /// Default audio buffer size for speech tap
    static let audioBufferSize: AVAudioFrameCount = 1024
}

// MARK: - SFSpeechRecognizerProvider

/// Speech recognition provider using Apple's SFSpeechRecognizer.
///
/// This provider uses the legacy Speech framework available on iOS 10+ and macOS 10.15+.
/// It captures audio using AVAudioEngine and transcribes using SFSpeechRecognizer.
@Observable
@MainActor
public final class SFSpeechRecognizerProvider: NSObject, SpeechRecognitionProvider {
    // MARK: - Type Properties

    public static let identifier: String = "com.apple.sfspeechrecognizer"

    public static var isAvailable: Bool {
        SFSpeechRecognizer()?.isAvailable ?? false
    }

    // MARK: - Instance Properties

    public private(set) var isListening: Bool = false
    public private(set) var authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    public private(set) var partialTranscription: String = ""

    /// Stream continuation for emitting results
    private var resultsContinuation: AsyncStream<SpeechRecognitionResult>.Continuation?

    /// The results stream (created once at init to ensure single continuation)
    public private(set) var results: AsyncStream<SpeechRecognitionResult>

    // MARK: - Private Properties

    /// Duration of silence before considering speech ended (seconds)
    private let silenceThreshold: TimeInterval

    /// Timer for silence detection
    private var silenceTimer: Task<Void, Never>?

    /// The audio engine for capturing audio
    private var audioEngine: AVAudioEngine?

    /// The speech recognizer
    private var speechRecognizer: SFSpeechRecognizer?

    /// The current recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// The current recognition task
    private var recognitionTask: SFSpeechRecognitionTask?

    // MARK: - Lifecycle

    /// Creates a new SFSpeechRecognizerProvider.
    /// - Parameter silenceThreshold: Seconds of silence before speech is considered ended (default: 1.5)
    public init(silenceThreshold: TimeInterval = 1.5) {
        self.silenceThreshold = silenceThreshold

        // Create results stream once to ensure single continuation
        // Using makeStream() allows initialization before super.init()
        let (stream, continuation) = AsyncStream.makeStream(of: SpeechRecognitionResult.self)
        self.results = stream
        self.resultsContinuation = continuation

        super.init()
        updateAuthorizationStatus()
    }

    // MARK: - Public Methods

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        // Request speech recognition authorization using nonisolated helper
        // to avoid MainActor isolation being inherited by the callback
        let speechStatus = await Self.requestSpeechAuthorization()

        guard speechStatus == .authorized else {
            let mapped = mapAuthorizationStatus(speechStatus)
            authorizationStatus = mapped
            return mapped
        }

        // Request microphone authorization
        let micStatus: Bool = await requestMicrophonePermission()

        let finalStatus: SpeechAuthorizationStatus = micStatus ? .authorized : .denied
        authorizationStatus = finalStatus
        return finalStatus
    }

    // MARK: - Private Static Methods

    /// Requests speech authorization without MainActor isolation.
    ///
    /// This is extracted as a static nonisolated function to ensure the callback
    /// from `SFSpeechRecognizer.requestAuthorization` doesn't inherit MainActor
    /// context, which would cause a dispatch assertion failure when the callback
    /// runs on a background queue.
    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    public func startListening(locale: Locale = .current) async throws {
        // Prevent overlapping sessions
        guard !isListening else { return }

        // Check authorization
        guard authorizationStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }

        // Verify microphone access is actually granted
        let microphoneGranted = await verifyMicrophoneAccess()
        guard microphoneGranted else {
            throw SpeechRecognitionError.notAuthorized
        }

        // Ensure any previous session is stopped
        stopListening()

        // Create speech recognizer for locale
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }

        speechRecognizer = recognizer
        partialTranscription = ""

        // Configure audio session
        try configureAudioSession()

        // Create and configure audio engine
        let engine = AVAudioEngine()
        audioEngine = engine

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        // Get input node and install tap
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        installSpeechTap(on: inputNode, format: inputFormat, request: request)

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Extract plain values off the callback thread
            let transcription: String? = result?.bestTranscription.formattedString
            let isFinal: Bool = result?.isFinal ?? false
            let confidence: Float = result?.bestTranscription.segments.first?.confidence ?? 1.0
            let errorMessage: String? = error?.localizedDescription
            let errorDomain: String? = (error as NSError?)?.domain
            let errorCode: Int? = (error as NSError?)?.code

            // Hop to MainActor before mutating observable state
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processRecognitionData(
                    transcription: transcription,
                    isFinal: isFinal,
                    confidence: confidence,
                    errorMessage: errorMessage,
                    errorDomain: errorDomain,
                    errorCode: errorCode
                )
            }
        }

        // Start audio engine
        engine.prepare()
        do {
            try engine.start()
            isListening = true
            startSilenceTimer()
        } catch {
            stopListening()
            throw SpeechRecognitionError.audioEngineError(error.localizedDescription)
        }
    }

    public func stopListening() {
        silenceTimer?.cancel()
        silenceTimer = nil

        // Remove tap first to stop producing buffers
        audioEngine?.inputNode.removeTap(onBus: 0)

        // End audio on the request before stopping the engine
        recognitionRequest?.endAudio()

        // Now stop the engine
        audioEngine?.stop()

        // Cancel any active recognition task
        recognitionTask?.cancel()

        // Cleanup references
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil
        isListening = false

        // Note: Do NOT finish the results stream here.
        // The stream should remain alive for the lifetime of the provider
        // so it can be reused when startListening() is called again.
    }

    // MARK: - Private Methods

    private nonisolated func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return true
        }
        #else
        if #available(iOS 17.0, visionOS 1.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #endif
    }

    private nonisolated func verifyMicrophoneAccess() async -> Bool {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return true
        }
        #else
        if #available(iOS 17.0, visionOS 1.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
        #endif
    }

    private func configureAudioSession() throws {
        #if os(iOS) || os(visionOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #elseif os(macOS)
        // macOS doesn't use AVAudioSession
        #endif
    }

    private func processRecognitionData(
        transcription: String?,
        isFinal: Bool,
        confidence: Float,
        errorMessage: String?,
        errorDomain: String?,
        errorCode: Int?
    ) {
        // Handle error
        if errorMessage != nil {
            // Ignore cancellation errors (user stopped listening)
            let isCancellation = errorDomain == SpeechRecognitionConstants.assistantErrorDomain
                && errorCode == SpeechRecognitionConstants.cancelledErrorCode
            if isCancellation {
                return
            }
            let errorResult = SpeechRecognitionResult(
                text: "",
                isFinal: true,
                confidence: 0
            )
            resultsContinuation?.yield(errorResult)
            stopListening()
            return
        }

        guard let transcription else { return }

        partialTranscription = transcription
        resetSilenceTimer()

        // Emit partial result
        let result = SpeechRecognitionResult(
            text: transcription,
            isFinal: isFinal,
            confidence: confidence
        )
        resultsContinuation?.yield(result)

        if isFinal {
            finishRecognition(with: transcription, confidence: confidence)
        }
    }

    private func startSilenceTimer() {
        silenceTimer?.cancel()
        let threshold = silenceThreshold
        silenceTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(threshold))
            guard !Task.isCancelled else { return }
            self?.handleSilenceTimeout()
        }
    }

    private func resetSilenceTimer() {
        guard isListening else { return }
        startSilenceTimer()
    }

    private func handleSilenceTimeout() {
        guard isListening, !partialTranscription.isEmpty else { return }
        finishRecognition(with: partialTranscription, confidence: 1.0)
    }

    private func finishRecognition(with text: String, confidence: Float) {
        let result = SpeechRecognitionResult(
            text: text,
            isFinal: true,
            confidence: confidence
        )
        resultsContinuation?.yield(result)
        stopListening()
    }

    private func updateAuthorizationStatus() {
        let status = SFSpeechRecognizer.authorizationStatus()
        authorizationStatus = mapAuthorizationStatus(status)
    }

    private nonisolated func mapAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
}

#else

// MARK: - Stub for platforms without Speech framework

import Foundation

@Observable
@MainActor
public final class SFSpeechRecognizerProvider: SpeechRecognitionProvider {
    public static let identifier: String = "com.apple.sfspeechrecognizer"
    public static var isAvailable: Bool { false }

    public private(set) var isListening: Bool = false
    public private(set) var authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    public private(set) var partialTranscription: String = ""
    public private(set) var results: AsyncStream<SpeechRecognitionResult>

    public init(silenceThreshold: TimeInterval = 1.5) {
        let (stream, _) = AsyncStream.makeStream(of: SpeechRecognitionResult.self)
        self.results = stream
    }

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        authorizationStatus = .denied
        return .denied
    }

    public func startListening(locale: Locale = .current) async throws {
        throw SpeechRecognitionError.notAvailable
    }

    public func stopListening() {
        isListening = false
    }
}

#endif
