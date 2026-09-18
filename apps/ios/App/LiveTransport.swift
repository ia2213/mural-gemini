import Foundation
import AVFoundation
import MuralCore

enum ConnectionState: Equatable { case idle, connecting, active, closing, ended, failed }

final class NativeSynthesizer: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    @MainActor private let synth = AVSpeechSynthesizer()
    @MainActor func speak(text: String, languageCode: String = "de-DE") {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let bcp = Self.bcp47Code(for: languageCode)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: bcp)
        utterance.rate = 0.50
        synth.speak(utterance)
    }
    @MainActor func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
    private static func bcp47Code(for id: String) -> String {
        switch id.lowercased() {
        case "de", "german": return "de-DE"
        case "fr", "french": return "fr-FR"
        case "es", "spanish": return "es-ES"
        case "it", "italian": return "it-IT"
        case "nb", "no", "norwegian": return "nb-NO"
        case "zh", "mandarin", "chinese": return "zh-CN"
        case "ja", "japanese": return "ja-JP"
        case "ar", "arabic": return "ar-SA"
        default: return id.contains("-") ? id : "\(id)-\(id.uppercased())"
        }
    }
    private static func bestVoice(for bcp47: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(bcp47.prefix(2)).lowercased()
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.lowercased().hasPrefix(prefix) }
        if let premium = voices.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) { return enhanced }
        return AVSpeechSynthesisVoice(language: bcp47) ?? AVSpeechSynthesisVoice(language: "de-DE")
    }
}

@MainActor final class LiveTransport: NSObject {
    var onEvent: (([String: Any]) -> Void)?
    var onLevels: ((Double, Double) -> Void)?
    var onFailure: ((String) -> Void)?
    
    private let synthesizer = NativeSynthesizer()
    private var recorder: AVAudioRecorder?
    private var audioURL: URL?
    private var meterTask: Task<Void, Never>?
    private var attempt = UUID()
    
    private(set) var started = false
    private(set) var isMuted = false
    private var closing = false
    private var ownsAudioActivation = false
    private var isProcessingSpeech = false
    
    private var api: APIClient?
    private var instructions: String = ""
    private var languageCode: String = "de-DE"
    
    func connect(api: APIClient, instructions: String, history: [[String: Any]], languageCode: String = "de-DE") async throws {
        disconnect()
        closing = false
        self.api = api
        self.instructions = instructions
        self.languageCode = languageCode
        let token = UUID(); attempt = token
        
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw TransportError.microphone }
        try Task.checkCancellation()
        guard attempt == token else { throw CancellationError() }
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        ownsAudioActivation = true
        
        let initialResult = try await api.respond(instructions: instructions, input: "Start conversation")
        guard attempt == token else { throw CancellationError() }
        let sessionID = UUID().uuidString
        onEvent?(["type": "mural.session.created", "session": ["id": sessionID]])
        started = true
        onEvent?(["type": "session.started", "session": ["id": sessionID]])
        
        if !initialResult.text.isEmpty {
            onEvent?(["type": "session.output_transcript.delta", "delta": initialResult.text, "start_ms": 0, "end_ms": 1000, "event_id": UUID().uuidString])
            synthesizer.speak(text: initialResult.text, languageCode: languageCode)
        }
        
        startRecording()
        startAudioLoop()
    }
    
    private func startRecording() {
        guard !closing else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mural_mic_\(UUID().uuidString).m4a")
        audioURL = url
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            print("Recorder error:", error)
        }
    }
    
    private func startAudioLoop() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            var speechDetected = false
            var silenceStart: Date? = nil
            
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.started, !self.isMuted, !self.isProcessingSpeech else { continue }
                guard let rec = self.recorder, rec.isRecording else { continue }
                
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)
                let level = max(0.0, min(1.0, Double(power + 50) / 50.0))
                self.onLevels?(level, 0)
                
                if power > -38 {
                    speechDetected = true
                    silenceStart = nil
                } else if speechDetected {
                    if silenceStart == nil { silenceStart = Date() }
                    if let start = silenceStart, Date().timeIntervalSince(start) >= 1.2 {
                        speechDetected = false
                        silenceStart = nil
                        Task { @MainActor [weak self] in
                            await self?.processSpokenAudio()
                        }
                    }
                }
            }
        }
    }
    
    private func processSpokenAudio() async {
        guard !isProcessingSpeech, let rec = recorder, let url = audioURL, let api else { return }
        isProcessingSpeech = true
        rec.stop()
        self.recorder = nil
        
        guard let data = try? Data(contentsOf: url), data.count > 2000 else {
            try? FileManager.default.removeItem(at: url)
            isProcessingSpeech = false
            startRecording()
            return
        }
        
        onLevels?(0, 0.5)
        
        do {
            let lang = String(languageCode.prefix(2))
            let userText = try await api.transcribe(audioData: data, language: lang)
            try? FileManager.default.removeItem(at: url)
            
            if !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onEvent?(["type": "session.input_transcript.delta", "delta": userText, "start_ms": 0, "end_ms": 1000, "event_id": UUID().uuidString])
                
                let result = try await api.respond(instructions: instructions, input: userText)
                if !result.text.isEmpty {
                    onEvent?(["type": "session.output_transcript.delta", "delta": result.text, "start_ms": 0, "end_ms": 1000, "event_id": UUID().uuidString])
                    synthesizer.speak(text: result.text, languageCode: languageCode)
                }
            }
        } catch {
            print("Speech processing error:", error)
            try? FileManager.default.removeItem(at: url)
        }
        
        isProcessingSpeech = false
        startRecording()
    }
    
    func speak(_ text: String, languageCode: String = "de-DE") {
        synthesizer.speak(text: text, languageCode: languageCode)
    }
    
    @discardableResult func send(_ event: [String: Any]) -> Bool {
        return true
    }
    
    func mute(_ muted: Bool) {
        isMuted = muted
        if muted {
            synthesizer.stop()
            recorder?.pause()
            onLevels?(0, 0)
        } else {
            recorder?.record()
        }
    }
    
    func close() {
        closing = true
        synthesizer.stop()
        recorder?.stop()
    }
    
    func disconnect() {
        attempt = UUID()
        meterTask?.cancel()
        meterTask = nil
        started = false
        closing = true
        synthesizer.stop()
        recorder?.stop()
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
            audioURL = nil
        }
        recorder = nil
        if ownsAudioActivation {
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false)
            ownsAudioActivation = false
        }
        onLevels?(0, 0)
    }

    enum TransportError: LocalizedError {
        case microphone, connection, timeout
        var errorDescription: String? {
            switch self {
            case .microphone: "Allow microphone access in iPhone Settings → Mural to start a conversation."
            case .connection: "The voice connection couldn’t be established. Check your connection and try again."
            case .timeout: "The voice connection took too long. Please try again."
            }
        }
    }
}
