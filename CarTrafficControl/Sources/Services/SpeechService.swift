import Foundation
import AVFoundation
import Speech

class SpeechService: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    // Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()
    
    // Speech-to-Text
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Text to Speech
    
    func speak(_ text: String, withCallSign callSign: String) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create utterance with ATC-style voice
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slightly slower speech rate
        utterance.pitchMultiplier = 1.0 // Normal pitch
        utterance.volume = 0.9 // Slightly lower volume
        
        // Apply audio processing for radio effect
        // This is a simple approach - in a real app you'd use AVAudioEngine for better effects
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
        
        isSpeaking = true
        synthesizer.speak(utterance)
        
        // Set up notification for when speech finishes
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(speechDidFinish), 
                                              name: AVSpeechSynthesizer.didFinishSpeechUtteranceNotification, 
                                              object: synthesizer)
    }
    
    @objc private func speechDidFinish() {
        isSpeaking = false
    }
    
    // MARK: - Speech Recognition
    
    func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.speechAuthorizationStatus = status
            }
        }
    }
    
    func startListening() {
        // Check authorization
        if speechAuthorizationStatus != .authorized {
            return
        }
        
        // Stop any existing recognition task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Check for input node and recognition request
        guard let inputNode = audioEngine.inputNode,
              let recognitionRequest = recognitionRequest else {
            return
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.isListening = false
            }
        }
        
        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try? audioEngine.start()
        
        isListening = true
        recognizedText = ""
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            isListening = false
            stopListening()
        }
    }
}