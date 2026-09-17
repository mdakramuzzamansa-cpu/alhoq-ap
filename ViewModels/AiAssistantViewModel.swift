import Foundation
import AVFoundation
import Speech

struct AiMessage: Identifiable, Equatable {
    let id = UUID()
    var role: String   // "user" | "model"
    var text: String
}

@MainActor
final class AiAssistantViewModel: NSObject, ObservableObject {
    @Published var messages: [AiMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var isRecording = false
    @Published var errorMessage: String?
    @Published var lang: String = "bn"   // web ডিফল্ট — Section 30

    private let api: AiAssistantAPIProtocol = AiAssistantAPI()
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "bn-BD"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func sendText() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        await send(text)
    }

    /// zip: history সর্বোচ্চ ২০ টার্ন — Gemini role কনভেনশন অনুযায়ী "user"/"model"
    private func send(_ text: String) async {
        messages.append(AiMessage(role: "user", text: text))
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let history = messages.dropLast().map { AiChatTurn(role: $0.role, text: $0.text) }

        do {
            let response = try await api.chat(message: text, history: Array(history), lang: lang)
            messages.append(AiMessage(role: "model", text: response.reply))
            await speak(response.reply)

            // zip: action.url ইতিমধ্যে backend-resolved পূর্ণ URL — সরাসরি deep-link router-এ
            if let action = response.action {
                DeepLinkRouter.shared.pendingURL = action.url
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = lang == "en" ? "Sorry, something went wrong." : "দুঃখিত, একটু সমস্যা হয়েছে।"
        }
    }

    // MARK: - Text-to-Speech (server proxy, device fallback)

    private func speak(_ text: String) async {
        if let audioData = try? await api.tts(text: text, lang: lang) {
            audioPlayer = try? AVAudioPlayer(data: audioData)
            audioPlayer?.play()
        } else {
            // zip comment হুবহু: "front-end শুধু তখনই browser-এর নিজস্ব voice-এ fallback করে
            // যখন server TTS ব্যর্থ হয় (offline ইত্যাদি)" — iOS-এ AVSpeechSynthesizer সেই fallback
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: lang == "en" ? "en-US" : "bn-BD")
            speechSynthesizer.speak(utterance)
        }
    }

    // MARK: - Speech-to-Text (voice input)

    func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            Task { @MainActor in self?.beginRecordingSession() }
        }
    }

    private func beginRecordingSession() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "ভয়েস রিকগনিশন এখন উপলব্ধ না।"
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.inputText = result.bestTranscription.formattedString }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in self.stopRecording() }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        // রেকর্ডিং শেষ হলে transcribed টেক্সট সাথে সাথে পাঠিয়ে দেওয়া (web widget-এর মতোই voice→send)
        let text = inputText
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            Task { await send(text); inputText = "" }
        }
    }
}
