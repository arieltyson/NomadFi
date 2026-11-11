// SpeechTranscribing.swift
// NomadFi
//
// Turns what the person says into text, on this iPhone only.

import AVFoundation
import Foundation
import Speech

/// Why listening could not start.
enum SpeechTranscriptionError: Error, Equatable, Sendable {
    /// Microphone or Speech Recognition access is off for NomadFi.
    case permissionDenied
    /// This iPhone or language cannot recognise speech on device.
    case onDeviceUnavailable
    /// The microphone could not be started.
    case audioUnavailable
}

/// Listens and yields the transcript so far, until stopped.
protocol SpeechTranscribing: Sendable {
    /// Starts listening. The stream yields each updated transcript and
    /// ends when recognition finishes or ``stop()`` is called.
    func transcripts() async throws -> AsyncStream<String>
    func stop() async
}

/// On-device speech recognition.
///
/// Audio never leaves the iPhone: recognition is required to run on
/// device, and if this iPhone or language cannot do that, listening is
/// refused rather than falling back to a server. Nothing is recorded to
/// disk; audio buffers go straight to the recogniser and are dropped.
actor OnDeviceSpeechTranscriber: SpeechTranscribing {

    private var engine: AVAudioEngine?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var continuation: AsyncStream<String>.Continuation?

    func transcripts() async throws -> AsyncStream<String> {
        await stop()
        guard await Self.hasPermission() else { throw SpeechTranscriptionError.permissionDenied }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw SpeechTranscriptionError.onDeviceUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        let engine = AVAudioEngine()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            Self.installTap(on: engine, feeding: request)
            engine.prepare()
            try engine.start()
        } catch {
            throw SpeechTranscriptionError.audioUnavailable
        }

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        self.engine = engine
        self.request = request
        self.continuation = continuation
        self.task = Self.recognize(request, with: recognizer, into: continuation)
        return stream
    }

    func stop() async {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        continuation?.finish()
        engine = nil; request = nil; task = nil; continuation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Callbacks
    //
    // These run on audio and recognition threads. They are built in
    // nonisolated functions so the closures carry no actor isolation.

    private nonisolated static func installTap(on engine: AVAudioEngine, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let input = engine.inputNode
        nonisolated(unsafe) let request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func recognize(
        _ request: SFSpeechAudioBufferRecognitionRequest,
        with recognizer: SFSpeechRecognizer,
        into continuation: AsyncStream<String>.Continuation
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                continuation.yield(result.bestTranscription.formattedString)
                if result.isFinal { continuation.finish() }
            }
            if error != nil { continuation.finish() }
        }
    }

    private nonisolated static func hasPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
