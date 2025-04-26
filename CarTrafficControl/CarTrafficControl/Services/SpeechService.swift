import Foundation
import AVFoundation
import Speech

class SpeechService: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    // Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()
    
    // Speech-to-Text
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Audio processing
    private let audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    private var mixerNode = AVAudioMixerNode()
    
    // Speech recognition engine (separate from audio effects)
    private let speechRecognitionEngine = AVAudioEngine()
    
    // Communication settings
    private var currentMessage: String = ""
    private var wordSegments: [String] = []
    private var currentSegmentIndex = 0
    private var wordTimer: Timer?
    
    // Pre-recorded radio click sounds - search in various paths
    private var clickInURL: URL? {
        // Try different possible paths for the click-in sound
        let paths = [
            Bundle.main.url(forResource: "radio_click_in", withExtension: "mp3"),
            Bundle.main.url(forResource: "radio_click_in", withExtension: "mp3", subdirectory: "Audio"),
            Bundle.main.url(forResource: "radio_click_in", withExtension: "mp3", subdirectory: "Resources/Audio")
        ]
        return paths.compactMap { $0 }.first
    }
    
    private var clickOutURL: URL? {
        // Try different possible paths for the click-out sound
        let paths = [
            Bundle.main.url(forResource: "radio_click_out", withExtension: "mp3"),
            Bundle.main.url(forResource: "radio_click_out", withExtension: "mp3", subdirectory: "Audio"),
            Bundle.main.url(forResource: "radio_click_out", withExtension: "mp3", subdirectory: "Resources/Audio")
        ]
        return paths.compactMap { $0 }.first
    }
    
    // Static audio has been removed from the project
    private var clickInPlayer: AVAudioPlayer?
    private var clickOutPlayer: AVAudioPlayer?
    
    // Sample playback completion handler
    private var sampleCompletionHandler: (() -> Void)?
    
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var isSpeaking = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        synthesizer.delegate = self
        
        print("🔊 DEBUG: Initializing SpeechService")
        
        // Make sure both engines are stopped and in a clean state
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if speechRecognitionEngine.isRunning {
            speechRecognitionEngine.stop()
        }
        
        // Critical: Configure quality settings for speech synthesizer
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playback mode with high quality audio
            print("🔊 DEBUG: Setting audio session category to playback with mixWithOthers")
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("🔊 DEBUG: Audio session activated successfully")
            print("🔊 DEBUG: Current audio session category: \(audioSession.category.rawValue)")
            print("🔊 DEBUG: Current audio session mode: \(audioSession.mode.rawValue)")
            print("🔊 DEBUG: Current audio session options: \(audioSession.categoryOptions.rawValue)")
        } catch {
            print("🔊 ERROR: Could not configure audio session: \(error)")
        }
        
        // Set direct voice testing mode for debugging
        // IMPORTANT: Change this to true to test voice directly without effects
        setDirectVoiceTestingMode(enabled: false)
        
        // Ensure we can use high-quality voices
        loadHighQualityVoices()
        setupRadioAudioEngine()
        prepareRadioSoundEffects()
        
        // Verify audio setup is correct
        print("🔊 DEBUG: SpeechService initialization complete")
        let currentSession = AVAudioSession.sharedInstance()
        print("🔊 DEBUG: Final audio session configuration:")
        print("🔊 DEBUG: - Category: \(currentSession.category.rawValue)")
        print("🔊 DEBUG: - Mode: \(currentSession.mode.rawValue)")
        print("🔊 DEBUG: - Options: \(currentSession.categoryOptions.rawValue)")
        print("🔊 DEBUG: - Sample rate: \(currentSession.sampleRate)")
        print("🔊 DEBUG: - isOtherAudioPlaying: \(currentSession.isOtherAudioPlaying)")
    }
    
    // Helper to set direct voice testing mode
    func setDirectVoiceTestingMode(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "DEBUG_DIRECT_VOICE")
        print("🔊 Direct voice testing mode: \(enabled ? "ENABLED" : "DISABLED") 🔊")
    }
    
    private func loadHighQualityVoices() {
        // List available voices to debug console
        print("Available voices on this device:")
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        for voice in allVoices {
            print("Voice: \(voice.name) (\(voice.language)), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)")
        }
        
        // Look for premium voices
        let premiumVoices = allVoices.filter { $0.quality.rawValue >= 10 }
        print("Number of premium voices: \(premiumVoices.count)")
        
        // Preload voices for better performance
        if let bestVoice = premiumVoices.first(where: { $0.language.starts(with: "en") }) {
            let warmupUtterance = AVSpeechUtterance(string: "Initializing")
            warmupUtterance.voice = bestVoice
            warmupUtterance.volume = 0  // Silent initialization
            synthesizer.speak(warmupUtterance)
        }
    }
    
    // MARK: - Radio Effect Setup
    
    private func setupRadioAudioEngine() {
        // Create a more sophisticated audio chain for radio effects
        let mainMixer = audioEngine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)
        
        // Configure effect nodes
        let distortionEffect = AVAudioUnitDistortion()
        let eqEffect = AVAudioUnitEQ(numberOfBands: 3)
        let reverbEffect = AVAudioUnitReverb()
        
        // Attach nodes to engine
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(distortionEffect)
        audioEngine.attach(eqEffect)
        audioEngine.attach(reverbEffect)
        audioEngine.attach(mixerNode)
        
        // Connect nodes
        audioEngine.connect(audioPlayerNode, to: distortionEffect, format: format)
        audioEngine.connect(distortionEffect, to: eqEffect, format: format)
        audioEngine.connect(eqEffect, to: reverbEffect, format: format)
        audioEngine.connect(reverbEffect, to: mixerNode, format: format)
        audioEngine.connect(mixerNode, to: mainMixer, format: format)
        
        // Configure effects for radio sound
        
        // Distortion - mild amp/tube simulation
        distortionEffect.loadFactoryPreset(.speechRadioTower)
        distortionEffect.wetDryMix = 40
        
        // EQ - radio frequency response 
        if let bands = eqEffect.bands as? [AVAudioUnitEQFilterParameters] {
            if bands.count >= 3 {
                // Cut low frequencies (below 300Hz)
                bands[0].filterType = .highPass
                bands[0].frequency = 300
                bands[0].bypass = false
                
                // Boost midrange for voice clarity (1kHz-3kHz)
                bands[1].filterType = .parametric
                bands[1].frequency = 2000
                bands[1].bandwidth = 1.0
                bands[1].gain = 6.0
                bands[1].bypass = false
                
                // Cut high frequencies (above 3.5kHz)
                bands[2].filterType = .lowPass
                bands[2].frequency = 3500
                bands[2].bypass = false
            }
        }
        
        // Very light reverb for spatial effect (simulates radio environment)
        reverbEffect.loadFactoryPreset(.smallRoom)
        reverbEffect.wetDryMix = 10
        
        // Set mixer levels
        mixerNode.outputVolume = 1.0
        
        // Start engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }
    
    private func prepareRadioSoundEffects() {
        // Load radio click and static sounds
        print("🔊 DEBUG: Preparing radio sound effects")
        
        // Print bundle paths for debugging
        print("🔊 DEBUG: Bundle path: \(Bundle.main.bundlePath)")
        print("🔊 DEBUG: Resource paths: \(Bundle.main.resourcePath ?? "none")")
        
        // List all files in Resources directory for debugging
        if let resourcePath = Bundle.main.resourcePath {
            let fileManager = FileManager.default
            print("🔊 DEBUG: Listing files in resource directory:")
            do {
                let items = try fileManager.contentsOfDirectory(atPath: resourcePath)
                for item in items {
                    print("🔊 DEBUG: Found: \(item)")
                }
                
                // Also check Resources/Audio if it exists
                let audioPath = resourcePath + "/Resources/Audio"
                if fileManager.fileExists(atPath: audioPath) {
                    print("🔊 DEBUG: Listing files in audio directory:")
                    let audioItems = try fileManager.contentsOfDirectory(atPath: audioPath)
                    for item in audioItems {
                        print("🔊 DEBUG: Found audio file: \(item)")
                    }
                } else {
                    print("🔊 DEBUG: Audio directory not found at: \(audioPath)")
                }
            } catch {
                print("🔊 ERROR: Could not list files: \(error)")
            }
        }
        
        if let clickInURL = clickInURL {
            print("🔊 DEBUG: Found click-in URL: \(clickInURL.path)")
            do {
                clickInPlayer = try AVAudioPlayer(contentsOf: clickInURL)
                clickInPlayer?.prepareToPlay()
                clickInPlayer?.volume = 0.7
                print("🔊 DEBUG: Click-in player initialized successfully")
            } catch {
                print("🔊 ERROR: Failed to create click-in player: \(error)")
            }
        } else {
            print("🔊 ERROR: Click-in URL is nil")
        }
        
        if let clickOutURL = clickOutURL {
            print("🔊 DEBUG: Found click-out URL: \(clickOutURL.path)")
            do {
                clickOutPlayer = try AVAudioPlayer(contentsOf: clickOutURL)
                clickOutPlayer?.prepareToPlay()
                clickOutPlayer?.volume = 0.7
                print("🔊 DEBUG: Click-out player initialized successfully")
            } catch {
                print("🔊 ERROR: Failed to create click-out player: \(error)")
            }
        } else {
            print("🔊 ERROR: Click-out URL is nil")
        }
        
        // Static audio has been removed
        
        // Create basic sounds if audio files aren't available
        if clickInPlayer == nil || clickOutPlayer == nil {
            print("🔊 DEBUG: Some players are nil, creating basic sounds")
            createBasicRadioSounds()
        }
    }
    
    private func createBasicRadioSounds() {
        // If we don't have the audio files, create the sounds programmatically
        // This is a simplified implementation - would be much better with real recordings
        print("Using programmatically generated radio sounds")
    }
    
    // MARK: - Voice Processing
    
    // Regular speak with full effects
    func speak(_ text: String, withCallSign callSign: String) {
        // Check for DEBUG_DIRECT_VOICE flag in UserDefaults
        let useDirectVoice = UserDefaults.standard.bool(forKey: "DEBUG_DIRECT_VOICE")
        
        if useDirectVoice {
            // Use simplified voice testing mode
            speakDirectTest(text, withCallSign: callSign)
        } else {
            // Use full processing
            speakWithFullProcessing(text, withCallSign: callSign)
        }
    }
    
    // Simplified direct speech testing function
    private func speakDirectTest(_ text: String, withCallSign callSign: String) {
        print("🔊 DIRECT VOICE TEST MODE 🔊")
        
        // Stop any ongoing speech
        if isSpeaking {
            stopSpeaking()
        }
        
        // Configure audio session for best quality
        configureAudioForHighQualitySpeech()
        
        isSpeaking = true
        
        // Use consistent text processing logic
        var messageText = text
        
        // Make sure it starts with callsign
        if !messageText.hasPrefix(callSign) {
            messageText = "\(callSign), \(messageText)"
        }
        
        // Make sure it ends with period
        if !messageText.hasSuffix(".") {
            messageText = "\(messageText)."
        }
        
        print("Speaking: \(messageText)")
        
        // Create utterance with full detailed logging
        let utterance = createRadioUtterance(for: messageText)
        
        // Speak directly without chunking or effects
        synthesizer.speak(utterance)
    }
    
    // Full processing with all effects
    private func speakWithFullProcessing(_ text: String, withCallSign callSign: String) {
        // Stop any ongoing speech
        if isSpeaking {
            stopSpeaking()
        }
        
        // Ensure high-quality audio output settings
        configureAudioForHighQualitySpeech()
        
        isSpeaking = true
        
        // Add classic radio transmission opening click/static
        playRadioOpeningSound()
        
        // Pre-process text for ATC style speech pattern
        currentMessage = processATCText(text, callSign: callSign)
        
        // Create speech chunks for more natural delivery with "breaks"
        let chunks = createSpeechChunks(from: currentMessage)
        
        // Start speaking with chunks
        speakWithDelays(chunks: chunks)
    }
    
    private func configureAudioForHighQualitySpeech() {
        // Configure audio session for highest quality voice synthesis
        let audioSession = AVAudioSession.sharedInstance()
        do {
            print("🔊 DEBUG: Configuring audio for high quality speech")
            // Use playback mode with highest quality settings
            try audioSession.setCategory(.playback, mode: .spokenAudio, 
                                        options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            
            // Set preferred sample rate and other audio quality parameters
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("🔊 DEBUG: High quality speech audio configured:")
            print("🔊 DEBUG: - Category: \(audioSession.category.rawValue)")
            print("🔊 DEBUG: - Mode: \(audioSession.mode.rawValue)")
            print("🔊 DEBUG: - Options: \(audioSession.categoryOptions.rawValue)")
            print("🔊 DEBUG: - mixWithOthers enabled: \(audioSession.categoryOptions.contains(.mixWithOthers))")
            print("🔊 DEBUG: - duckOthers enabled: \(audioSession.categoryOptions.contains(.duckOthers))")
        } catch {
            print("🔊 ERROR: Failed to configure audio session: \(error)")
        }
    }
    
    private func speakWithDelays(chunks: [String]) {
        var delay = 0.3 // Initial delay for radio click sound
        let chunksWithPauses = chunks
        
        // Schedule each chunk with appropriate delay
        for (index, chunk) in chunksWithPauses.enumerated() {
            // Calculate how long this chunk will take to speak (rough estimate)
            let wordCount = chunk.split(separator: " ").count
            let chunkDuration = Double(wordCount) * 0.3 // ~0.3 seconds per word
            
            // Schedule this chunk to be spoken after the delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.isSpeaking else { return }
                
                // Configure utterance with radio voice characteristics
                let utterance = self.createRadioUtterance(for: chunk)
                self.synthesizer.speak(utterance)
                
                // For the last chunk, add radio transmission closing click
                if index == chunksWithPauses.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + chunkDuration + 0.3) { [weak self] in
                        self?.playRadioClosingSound()
                    }
                }
            }
            
            // Increase delay for next chunk (current delay + duration of this chunk + pause)
            delay += chunkDuration + 0.15 // 0.15s pause between chunks
        }
    }
    
    private func createRadioUtterance(for text: String, preferredVoice: AVSpeechSynthesisVoice? = nil) -> AVSpeechUtterance {
        // Create the utterance
        let utterance = AVSpeechUtterance(string: text)
        
        // If there's a specific preferred voice, use that
        if let preferredVoice = preferredVoice {
            utterance.voice = preferredVoice
            print("Using specified voice: \(preferredVoice.name), ID: \(preferredVoice.identifier)")
        }
        // Otherwise check for user-selected voice from UserDefaults
        else if let selectedVoiceID = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier"),
                let selectedVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == selectedVoiceID }) {
            utterance.voice = selectedVoice
            print("Using user-selected voice: \(selectedVoice.name), ID: \(selectedVoice.identifier)")
        }
        // Otherwise use the original voice selection logic
        else {
            // Get all available voices for en-US
            let desiredLanguage = "en-US"
            let availableVoices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language == desiredLanguage }
            
            print("🔊 DEBUG: Searching for enhanced voices...")
            
            // Look specifically for Nathan enhanced voice first (now the default)
            if let nathanVoice = availableVoices.first(where: { 
                $0.name.contains("Nathan") && $0.identifier.contains("enhanced")
            }) {
                utterance.voice = nathanVoice
                print("🔊 DEBUG: Using Nathan enhanced voice: \(nathanVoice.identifier)")
            }
            // Then try any enhanced voice with "Nathan" in the name
            else if let nathanVoice = availableVoices.first(where: { 
                $0.name.contains("Nathan")
            }) {
                utterance.voice = nathanVoice
                print("🔊 DEBUG: Using Nathan voice: \(nathanVoice.identifier)")
            }
            // Then try Evan enhanced voice
            else if let evanVoice = availableVoices.first(where: { 
                $0.name.contains("Evan") && $0.identifier.contains("enhanced")
            }) {
                utterance.voice = evanVoice
                print("🔊 DEBUG: Using Evan enhanced voice: \(evanVoice.identifier)")
            }
            // Try any enhanced voice as backup
            else if let enhancedVoice = availableVoices.first(where: { 
                $0.identifier.contains("enhanced") || $0.quality.rawValue >= 10 
            }) {
                utterance.voice = enhancedVoice
                print("🔊 DEBUG: Using enhanced voice: \(enhancedVoice.name), \(enhancedVoice.identifier)")
            }
            // Try Tom Enhanced specifically
            else if let tomVoice = availableVoices.first(where: { 
                $0.name.contains("Tom") && ($0.identifier.contains("enhanced") || $0.quality.rawValue >= 10)
            }) {
                utterance.voice = tomVoice
                print("🔊 DEBUG: Using Tom enhanced voice: \(tomVoice.identifier)")
            }
            // Try any male voice
            else if let maleVoice = availableVoices.first(where: { 
                ["Alex", "Daniel", "Fred", "Tom", "Aaron"].contains($0.name) 
            }) {
                utterance.voice = maleVoice
                print("🔊 DEBUG: Using standard male voice: \(maleVoice.name), \(maleVoice.identifier)")
            }
            // Final fallback: Any voice
            else {
                utterance.voice = AVSpeechSynthesisVoice(language: desiredLanguage)
                print("🔊 DEBUG: Using default system voice: \(utterance.voice?.name ?? "Unknown")")
            }
            
            // Debug list of available enhanced voices
            print("🔊 DEBUG: Available enhanced voices:")
            for voice in availableVoices.filter({ $0.identifier.contains("enhanced") || $0.quality.rawValue > 1 }) {
                print("🔊 DEBUG: - \(voice.name) (\(voice.identifier)), Quality: \(voice.quality.rawValue)")
            }
        }
        
        // Configure voice characteristics for ATC style - using direct values for testing
        utterance.rate = 0.5                  // Specific rate (0.0-1.0)
        utterance.pitchMultiplier = 1.0       // Normal pitch for now
        utterance.volume = 1.0                // Full volume
        
        // Disable assistive technology settings for highest quality
        if #available(iOS 14.0, *) {
            utterance.prefersAssistiveTechnologySettings = false
        }
        
        print("*** SELECTED VOICE: \(utterance.voice?.name ?? "Unknown"), ID: \(utterance.voice?.identifier ?? "Unknown") ***")
        
        return utterance
    }
    
    private func processATCText(_ text: String, callSign: String) -> String {
        // Format text in ATC style
        var processedText = text
        
        // Structure with call sign at beginning only (if not already included)
        if !processedText.hasPrefix(callSign) {
            processedText = "\(callSign), \(processedText)"
        }
        
        // Add period if needed - never add callSign at the end
        if !processedText.hasSuffix(".") {
            processedText = "\(processedText)."
        }
        
        return processedText
    }
    
    private func createSpeechChunks(from text: String) -> [String] {
        // Split text into natural chunks based on punctuation and ATC parlance
        var chunks: [String] = []
        
        // First split by obvious break points
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".,:;"))
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                chunks.append(trimmed)
            }
        }
        
        // If we don't have enough natural break points, create them based on length
        if chunks.count <= 1 && text.count > 30 {
            chunks = []
            let words = text.components(separatedBy: " ")
            var currentChunk = ""
            
            for word in words {
                if currentChunk.count + word.count > 25 {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentChunk = word
                } else {
                    if !currentChunk.isEmpty {
                        currentChunk += " "
                    }
                    currentChunk += word
                }
            }
            
            if !currentChunk.isEmpty {
                chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        // If still no chunks, use the whole text
        if chunks.isEmpty {
            chunks = [text]
        }
        
        return chunks
    }
    
    // MARK: - Radio Sound Effects
    
    private func playRadioOpeningSound() {
        // Play the characteristic "click" sound of radio transmission starting
        print("🔊 DEBUG: Playing radio opening sound")
        if let clickPlayer = clickInPlayer, clickPlayer.isPlaying == false {
            print("🔊 DEBUG: Click player ready, playing now")
            clickPlayer.currentTime = 0
            clickPlayer.play()
            print("🔊 DEBUG: Click player started, isPlaying=\(clickPlayer.isPlaying)")
        } else {
            print("🔊 DEBUG: Click player not available or already playing")
            // Add a delay to simulate the click sound
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔊 DEBUG: Click delay completed")
            }
        }
        
        // Static audio has been removed
        print("🔊 DEBUG: Static audio removed")
    }
    
    private func playRadioClosingSound() {
        print("🔊 DEBUG: Playing radio closing sound - speech is complete")
        
        // Play the characteristic "click" sound of radio transmission ending
        if let clickPlayer = clickOutPlayer, clickPlayer.isPlaying == false {
            clickPlayer.currentTime = 0
            clickPlayer.play()
            
            // Set speaking to false after the click sound finishes with longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                print("🔊 DEBUG: Marking speech as officially ended")
                self?.isSpeaking = false
            }
        } else {
            // Add a delay to simulate the click sound with longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                print("🔊 DEBUG: Marking speech as officially ended (no click)")
                self?.isSpeaking = false
            }
        }
    }
    
    private func addRadioNoise(intensity: Float = 0.1) {
        // Static audio effect has been removed
        print("🔊 DEBUG: Radio static functionality removed")
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        wordTimer?.invalidate()
        wordTimer = nil
        isSpeaking = false
    }
    
    // MARK: - Voice Sample Preview
    
    func speakSample(_ voice: AVSpeechSynthesisVoice, completion: @escaping () -> Void) {
        // Store completion handler
        sampleCompletionHandler = completion
        
        // Configure audio for high quality
        configureAudioForHighQualitySpeech()
        
        // Create a 10-second sample text
        let sampleText = "This is a 10-second voice sample for the \(voice.name) voice. This voice will be used for all tower communications if selected. The sample continues to demonstrate how the voice sounds for a full 10 seconds so you can properly evaluate it."
        
        // Create utterance with the specified voice
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        if #available(iOS 14.0, *) {
            utterance.prefersAssistiveTechnologySettings = false
        }
        
        // Speak the sample
        synthesizer.speak(utterance)
    }
    
    // AVSpeechSynthesizerDelegate method
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Call the completion handler if this was a sample playback
        if let completionHandler = sampleCompletionHandler {
            completionHandler()
            sampleCompletionHandler = nil
        }
        
        // Individual utterances are handled by our chunking system, not here
        // The isSpeaking flag is set to false after the final radio click sound
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
        
        // Create a new audio engine for speech recognition to avoid conflicts
        speechRecognitionEngine.stop()
        
        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use record mode
            try audioSession.setCategory(.record, mode: .default, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("🎤 ERROR: Could not configure audio session for recording: \(error)")
            return
        }
        
        // Create a fresh recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Check for recognition request
        guard let recognitionRequest = recognitionRequest else {
            print("🎤 ERROR: Unable to create recognition request")
            return
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        
        // Start speechRecognitionEngine (completely separate from the audio effects engine)
        speechRecognitionEngine.reset() // Start fresh
        
        // Get the input node
        let inputNode = speechRecognitionEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // If there's an error, log it
                if let error = error {
                    print("🎤 ERROR: Speech recognition error: \(error)")
                }
                
                // Clean up
                self.speechRecognitionEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.isListening = false
            }
        }
        
        print("🎤 DEBUG: Setting up recording tap")
        
        // Configure microphone input with proper error handling
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Use a safer approach to installing the tap
        do {
            // Make sure there's no existing tap
            inputNode.removeTap(onBus: 0)
            
            // Install a new tap with proper buffer settings
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            print("🎤 DEBUG: Successfully installed tap on input node")
        } catch {
            print("🎤 ERROR: Failed to install tap: \(error)")
            return
        }
        
        // Start speech recognition engine with proper error handling
        speechRecognitionEngine.prepare()
        do {
            try speechRecognitionEngine.start()
            print("🎤 DEBUG: Successfully started speech recognition engine")
        } catch {
            print("🎤 ERROR: Failed to start speech recognition engine: \(error)")
            return
        }
        
        isListening = true
        recognizedText = ""
    }
    
    func stopListening() {
        print("🎤 DEBUG: Stopping listening")
        
        // End the recognition request first
        recognitionRequest?.endAudio()
        
        // Cancel any ongoing recognition task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // Remove any tap on the input node to prevent the crash
        if speechRecognitionEngine.isRunning {
            let inputNode = speechRecognitionEngine.inputNode
            inputNode.removeTap(onBus: 0)
        }
        
        // Stop the audio engine
        speechRecognitionEngine.stop()
        
        // Clean up resources
        recognitionRequest = nil
        
        // Update state
        isListening = false
        print("🎤 DEBUG: Successfully stopped listening")
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            isListening = false
            stopListening()
        }
    }
    
    // MARK: - App lifecycle cleanup
    
    // Call this method when the app is going to the background or terminating
    func cleanup() {
        print("🎤 DEBUG: Performing SpeechService cleanup")
        
        // Stop any speech
        stopSpeaking()
        
        // Stop any speech recognition
        stopListening()
        
        // Stop all audio engines
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if speechRecognitionEngine.isRunning {
            speechRecognitionEngine.stop()
        }
        
        // Reset state
        isSpeaking = false
        isListening = false
        
        print("🎤 DEBUG: SpeechService cleanup complete")
    }
}
