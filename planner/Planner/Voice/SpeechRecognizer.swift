import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error, LocalizedError {
        case recognizerUnavailable
        case audioUnavailable

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                "Speech recognition isn't available right now."
            case .audioUnavailable:
                "The microphone isn't available right now. Try again in a moment."
            }
        }
    }

    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Requests both speech-recognition and microphone access. Returns false if either is denied.
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        #if os(iOS)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }

    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw RecognizerError.recognizerUnavailable
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // AVAudioEngine.installTap crashes with an uncatchable Objective-C exception
        // (not a Swift error) if given a degenerate format — this can happen right
        // after the audio session activates, before the route has fully settled.
        // Validating first turns that potential crash into a graceful failure.
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            recognitionRequest = nil
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            throw RecognizerError.audioUnavailable
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            throw error
        }
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
