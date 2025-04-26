import SwiftUI
import AVFoundation

// Include VoiceSettings directly in file to avoid import issues
class VoiceSettings: ObservableObject {
    // Keys for UserDefaults
    private let selectedVoiceKey = "selectedVoiceIdentifier"
    
    // Published properties
    @Published var selectedVoiceIdentifier: String? {
        didSet {
            if let identifier = selectedVoiceIdentifier {
                UserDefaults.standard.set(identifier, forKey: selectedVoiceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedVoiceKey)
            }
        }
    }
    
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    
    init() {
        // Load saved voice preference
        selectedVoiceIdentifier = UserDefaults.standard.string(forKey: selectedVoiceKey)
        
        // Load available voices
        refreshAvailableVoices()
    }
    
    func refreshAvailableVoices() {
        // Log all available voices to understand what's available
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        print("All available voices:")
        for voice in allVoices where voice.language.starts(with: "en") {
            print("Voice: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)")
        }
        
        // Filter by:
        // 1. English language
        // 2. Must contain "Enhanced" or "Premium" in the name - looking at iOS UI
        //    we can see these are clearly marked in the official voice name
        availableVoices = allVoices
            .filter { voice in 
                voice.language.starts(with: "en") && 
                (voice.name.contains("Enhanced") || voice.name.contains("Premium"))
            }
            .sorted { $0.name < $1.name }
            
        // Log the filtered voices
        print("Filtered Enhanced/Premium voices:")
        for voice in availableVoices {
            print("Selected: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)")
        }
        
        // Auto-select first voice if there are voices but none selected
        if selectedVoiceIdentifier == nil && !availableVoices.isEmpty {
            selectedVoiceIdentifier = availableVoices[0].identifier
            print("Auto-selected voice in refreshAvailableVoices: \(availableVoices[0].name)")
        }
    }
    
    func getVoiceByIdentifier(_ identifier: String) -> AVSpeechSynthesisVoice? {
        return availableVoices.first { $0.identifier == identifier }
    }
}

struct ContentView: View {
    @StateObject private var speechService = SpeechService()
    @StateObject private var locationService = LocationService()
    @StateObject private var towerController: TowerController
    @StateObject private var voiceSettings = VoiceSettings()
    
    @State private var isSetupComplete = false
    
    init() {
        let speech = SpeechService()
        let location = LocationService()
        _speechService = StateObject(wrappedValue: speech)
        _locationService = StateObject(wrappedValue: location)
        _towerController = StateObject(wrappedValue: TowerController(speechService: speech, locationService: location))
    }
    
    var body: some View {
        if isSetupComplete {
            MainView(onReturnToSetup: {
                // Reset to setup view
                isSetupComplete = false
            })
                .environmentObject(speechService)
                .environmentObject(locationService)
                .environmentObject(towerController)
                .environmentObject(voiceSettings)
        } else {
            SetupView(onSetupComplete: {
                isSetupComplete = true
            })
            .environmentObject(towerController)
            .environmentObject(voiceSettings)
            .environmentObject(speechService)
        }
    }
}