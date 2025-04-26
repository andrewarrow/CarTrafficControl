import SwiftUI
import AVFoundation
import CoreLocation

// Include CompassService directly in file to avoid import issues
class CompassService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var heading: Double = 0.0
    @Published var isCalibrating: Bool = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        
        // Check if device has heading capability
        if CLLocationManager.headingAvailable() {
            startUpdatingHeading()
        }
    }
    
    func startUpdatingHeading() {
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use true heading if available (relative to true north), fallback to magnetic heading
        let headingValue = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        // Update the published heading value
        heading = headingValue
        
        // Reset calibration flag when we get valid readings
        if isCalibrating && newHeading.headingAccuracy >= 0 {
            isCalibrating = false
        }
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Return true to allow the system to display the heading calibration UI if needed
        isCalibrating = true
        return true
    }
}

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

// Compass View Component
struct CompassView: View {
    @EnvironmentObject var compassService: CompassService
    
    var body: some View {
        VStack {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                // Cardinal directions
                ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                    CompassDirectionText(direction: direction)
                }
                
                // Inner circle
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 70, height: 70)
                
                // Compass needle
                CompassNeedle()
                    .fill(Color.red)
                    .frame(width: 5, height: 60)
                    .offset(y: -15)
                    .rotationEffect(Angle(degrees: -compassService.heading))
                
                // Center circle
                Circle()
                    .fill(Color.blue)
                    .frame(width: 15, height: 15)
                
                if compassService.isCalibrating {
                    Text("Calibrating...")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .offset(y: 50)
                }
            }
            
            Text("\(Int(compassService.heading))°")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}

struct CompassDirectionText: View {
    let direction: String
    
    var body: some View {
        let angle = directionToAngle(direction)
        return Text(direction)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .offset(y: -45)
            .rotationEffect(Angle(degrees: -angle))
            .rotationEffect(Angle(degrees: angle))
    }
    
    private func directionToAngle(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

struct CompassNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create arrow shape
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width, y: height / 4))
        path.addLine(to: CGPoint(x: width / 2, y: height))
        path.addLine(to: CGPoint(x: 0, y: height / 4))
        path.closeSubpath()
        
        return path
    }
}

struct ContentView: View {
    @StateObject private var speechService = SpeechService()
    @StateObject private var locationService = LocationService()
    @StateObject private var towerController: TowerController
    @StateObject private var voiceSettings = VoiceSettings()
    // Create a local CompassService instance
    @StateObject private var compassService = CompassService()
    
    // Lifecycle manager to handle app state changes
    @EnvironmentObject private var lifecycleManager: AppLifecycleManager
    
    @State private var isSetupComplete = false
    
    // Single init function with optional parameter for testing
    init(lifecycleManager: AppLifecycleManager? = nil) {
        let speech = SpeechService()
        let location = LocationService()
        _speechService = StateObject(wrappedValue: speech)
        _locationService = StateObject(wrappedValue: location)
        _towerController = StateObject(wrappedValue: TowerController(speechService: speech, locationService: location))
        
        // If a lifecycle manager was passed directly (for tests), use it
        if let manager = lifecycleManager {
            manager.register(speechService: speech)
        }
    }
    
    var body: some View {
        Group {
            if isSetupComplete {
                MainView(onReturnToSetup: {
                    // Reset to setup view
                    isSetupComplete = false
                })
                    .environmentObject(speechService)
                    .environmentObject(locationService)
                    .environmentObject(towerController)
                    .environmentObject(voiceSettings)
                    .environmentObject(compassService)
            } else {
                SetupView(onSetupComplete: {
                    isSetupComplete = true
                })
                .environmentObject(towerController)
                .environmentObject(voiceSettings)
                .environmentObject(speechService)
            }
        }
        .onAppear {
            // Register services with the lifecycle manager when view appears
            registerServices()
        }
    }
    
    // Register services for app lifecycle management
    private func registerServices() {
        lifecycleManager.register(speechService: speechService)
        lifecycleManager.register(compassService: compassService)
    }
}