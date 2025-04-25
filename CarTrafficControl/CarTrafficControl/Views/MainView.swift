import SwiftUI
import AVFoundation

// Include VoiceSettingsView in the MainView file to avoid scope issues
struct VoiceSettingsView: View {
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var voiceSettings: VoiceSettings
    @Environment(\.dismiss) private var dismiss
    
    // For voice sample playback
    @State private var isSamplePlaying = false
    @State private var selectedVoiceForTest: AVSpeechSynthesisVoice?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Premium & Enhanced Voices"), footer: Text("Only voices marked as Premium or Enhanced are shown.")) {
                    if voiceSettings.availableVoices.isEmpty {
                        Text("No premium or enhanced voices found")
                            .foregroundColor(.secondary)
                    } else {
                        List {
                            ForEach(voiceSettings.availableVoices, id: \.identifier) { voice in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(voice.name)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                        
                                        Text(isPremiumVoice(voice) ? "Premium Voice" : "Enhanced Voice")
                                            .font(.caption)
                                            .foregroundColor(isPremiumVoice(voice) ? .blue : .secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Play sample button - 10 second sample
                                    Button(action: {
                                        playVoiceSample(voice)
                                    }) {
                                        HStack {
                                            Image(systemName: "play.circle")
                                            Text("Play")
                                        }
                                        .foregroundColor(.blue)
                                    }
                                    .disabled(isSamplePlaying)
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                                .background(voice.identifier == voiceSettings.selectedVoiceIdentifier ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    // Select this voice as the tower's voice
                                    voiceSettings.selectedVoiceIdentifier = voice.identifier
                                }
                            }
                        }
                    }
                }
                
                Section(footer: Text("The selected voice will be used for all tower communications.")) {
                    // Show current selected voice
                    if let selectedID = voiceSettings.selectedVoiceIdentifier,
                       let selectedVoice = voiceSettings.getVoiceByIdentifier(selectedID) {
                        HStack {
                            Text("Current Tower Voice:")
                            Spacer()
                            Text(selectedVoice.name)
                                .foregroundColor(.blue)
                                .bold()
                        }
                    }
                    
                    Button("Reset to Default Voice") {
                        voiceSettings.selectedVoiceIdentifier = nil
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Tower Voice Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                voiceSettings.refreshAvailableVoices()
            }
        }
    }
    
    private func isPremiumVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        // Premium voices have "Premium" in the name
        return voice.name.contains("Premium")
        // Enhanced voices will be the default case in the UI
    }
    
    private func playVoiceSample(_ voice: AVSpeechSynthesisVoice) {
        isSamplePlaying = true
        selectedVoiceForTest = voice
        speechService.speakSample(voice) {
            isSamplePlaying = false
        }
    }
}

struct MainView: View {
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var towerController: TowerController
    @EnvironmentObject var voiceSettings: VoiceSettings
    
    @State private var showingSettings = false
    
    var body: some View {
        ScrollView {
            VStack {
                // Header with call sign and settings button
                HStack {
                    if let callSign = towerController.userVehicle?.callSign {
                        Text("Call Sign: \(callSign)")
                            .font(.title2)
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                // Current location display
                locationInfoView
                
                // Tower messages
                messageListView
                
                // Tower status view
                controlsView
            }
            .padding()
        }
        .refreshable {
            // This will automatically show a progress view during refresh
            await towerController.requestNewTowerMessage()
        }
        .overlay(Group {
            if towerController.isRefreshing {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    )
            }
        })
        .onAppear {
            locationService.startLocationUpdates()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
            speechService.stopListening()
        }
        .sheet(isPresented: $showingSettings) {
            VoiceSettingsView()
                .environmentObject(speechService)
                .environmentObject(voiceSettings)
        }
    }
    
    private var locationInfoView: some View {
        VStack(alignment: .leading) {
            Text("Current Location:")
                .font(.headline)
            
            HStack {
                Image(systemName: "location.fill")
                if !locationService.currentCrossStreet.isEmpty {
                    Text("\(locationService.currentStreet) & \(locationService.currentCrossStreet)")
                } else {
                    Text(locationService.currentStreet)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var messageListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(zip(towerController.towerMessages.indices, towerController.towerMessages)), id: \.0) { _, message in
                    MessageBubbleView(message: message, isFromTower: true)
                }
                
                ForEach(Array(zip(towerController.userMessages.indices, towerController.userMessages)), id: \.0) { _, message in
                    MessageBubbleView(message: message, isFromTower: false)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    @Environment(\.colorScheme) var colorScheme

    private var controlsView: some View {
            
        VStack(spacing: 16) {
            HStack {
                if speechService.isSpeaking {
                    Text("Tower Speaking...")
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            
            if let last = towerController.userMessages.last {
                VStack(alignment: .leading) {
                    Text("Last message:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(last)
                        .foregroundColor(towerController.isCommunicationValid ? .green : .red)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct MessageBubbleView: View {
    let message: String
    let isFromTower: Bool
    
    var body: some View {
        HStack {
            if !isFromTower {
                Spacer()
            }
            
            Text(message)
                .padding()
                .background(isFromTower ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                .foregroundColor(isFromTower ? .primary : .primary)
                .cornerRadius(10)
                .frame(maxWidth: 300, alignment: isFromTower ? .leading : .trailing)
            
            if isFromTower {
                Spacer()
            }
        }
    }
}
