import SwiftUI

struct SetupView: View {
    @EnvironmentObject var towerController: TowerController
    @EnvironmentObject var voiceSettings: VoiceSettings
    @EnvironmentObject var speechService: SpeechService
    
    // Set Kia as default car make and empty license plate
    @State private var selectedCarMake: CarMake? = nil
    @State private var licensePlateDigits = ""
    @State private var showVoiceSettings = false
    
    var onSetupComplete: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Information")) {
                    Picker("Car Make", selection: $selectedCarMake) {
                        Text("Select a car make").tag(nil as CarMake?)
                        ForEach(popularCarMakes.dropFirst()) { make in
                            Text(make.name).tag(make as CarMake?)
                        }
                    }
                    
                    TextField("License Plate Digits (last 3-4)", text: $licensePlateDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: licensePlateDigits) { value in
                            if value.count > 4 {
                                licensePlateDigits = String(value.prefix(4))
                            }
                        }
                }
                
                Section(header: Text("Call Sign Preview")) {
                    if let make = selectedCarMake, !licensePlateDigits.isEmpty {
                        let callSign = "\(make.name.uppercased())\(licensePlateDigits)"
                        Text(callSign)
                            .font(.title2)
                            .bold()
                    } else {
                        Text("Complete form to see call sign")
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button("Start Car Traffic Control") {
                        // Refresh voices to ensure we have the latest
                        voiceSettings.refreshAvailableVoices()
                        
                        if let make = selectedCarMake, !licensePlateDigits.isEmpty {
                            // Check if user has premium/enhanced voices
                            if voiceSettings.availableVoices.isEmpty {
                                // No premium voices available, show voice settings instead
                                showVoiceSettings = true
                            } else {
                                // Always auto-select if we have voices but none selected
                                if voiceSettings.selectedVoiceIdentifier == nil || voiceSettings.getVoiceByIdentifier(voiceSettings.selectedVoiceIdentifier ?? "") == nil {
                                    // Auto-select the first available voice
                                    voiceSettings.selectedVoiceIdentifier = voiceSettings.availableVoices[0].identifier
                                    print("Auto-selected voice: \(voiceSettings.availableVoices[0].name) with ID: \(voiceSettings.availableVoices[0].identifier)")
                                    
                                    // Save to UserDefaults directly as an extra precaution
                                    UserDefaults.standard.set(voiceSettings.availableVoices[0].identifier, forKey: "selectedVoiceIdentifier")
                                    UserDefaults.standard.synchronize()
                                }
                                
                                // Continue to main app (either using existing or newly selected voice)
                                towerController.setUserVehicle(make: make, licensePlateDigits: licensePlateDigits)
                                onSetupComplete()
                            }
                        }
                    }
                    .disabled(selectedCarMake == nil || licensePlateDigits.isEmpty)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("CTC Setup")
        }
        .onAppear {
            requestPermissions()
            // Make sure we have the latest voice list
            voiceSettings.refreshAvailableVoices()
            
            // Load saved preferences
            loadSavedPreferences()
        }
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsView()
                .environmentObject(speechService)
                .environmentObject(voiceSettings)
        }
    }
    
    private func requestPermissions() {
        // This would be replaced by proper permission handling in a real app
        let locationService = LocationService()
        
        speechService.requestSpeechRecognitionPermission()
        locationService.requestLocationPermission()
    }
    
    private func loadSavedPreferences() {
        // Load saved car make
        if let savedMakeName = UserDefaults.standard.string(forKey: UserVehicle.makeKey) {
            selectedCarMake = popularCarMakes.first(where: { $0.name == savedMakeName })
        } else {
            // No default selection
            selectedCarMake = nil
        }
        
        // Load saved license plate
        if let savedLicensePlate = UserDefaults.standard.string(forKey: UserVehicle.licensePlateKey) {
            licensePlateDigits = savedLicensePlate
        }
    }
}