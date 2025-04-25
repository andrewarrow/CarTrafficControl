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
        // Get locally available voices for English
        // Note: speechVoices() returns voices currently available on the device
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: "en") }
            .sorted { $0.name < $1.name }
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
            MainView()
                .environmentObject(speechService)
                .environmentObject(locationService)
                .environmentObject(towerController)
                .environmentObject(voiceSettings)
        } else {
            SetupView(onSetupComplete: {
                isSetupComplete = true
            })
            .environmentObject(towerController)
        }
    }
}