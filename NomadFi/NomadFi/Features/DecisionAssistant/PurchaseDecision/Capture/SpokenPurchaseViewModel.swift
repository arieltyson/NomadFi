// SpokenPurchaseViewModel.swift
// NomadFi
//
// Listens, shows the transcript and reads the purchase out of it.

import Foundation
import Observation

@MainActor
@Observable
final class SpokenPurchaseViewModel {

    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var error: SpeechTranscriptionError?

    private let transcriber: any SpeechTranscribing

    init(transcriber: any SpeechTranscribing = OnDeviceSpeechTranscriber()) {
        self.transcriber = transcriber
    }

    /// What has been understood so far.
    var utterance: PurchaseUtterance { PurchaseUtteranceParser.parse(transcript) }

    /// Listens until recognition ends or ``stop()`` is called.
    func listen() async {
        error = nil
        do {
            let stream = try await transcriber.transcripts()
            isListening = true
            for await text in stream { transcript = text }
        } catch let failure as SpeechTranscriptionError {
            error = failure
        } catch {
            self.error = .audioUnavailable
        }
        isListening = false
    }

    func stop() async {
        await transcriber.stop()
        isListening = false
    }
}
