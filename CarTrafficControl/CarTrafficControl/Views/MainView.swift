import SwiftUI
import AVFoundation
import UIKit

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
                Section(header: Text("Premium & Enhanced Voices"), footer: Text("Only voices marked as Premium or Enhanced are shown. Go to Settings > Accessibility > Spoken Content > Voices > English > Voice and download enhanced voices")) {
                    if voiceSettings.availableVoices.isEmpty {
                        VStack(spacing: 10) {
                            Text("No premium or enhanced voices found")
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let url = URL(string: "App-Prefs:root=ACCESSIBILITY&path=SPEECH") {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                }
                            }) {
                                Text("Go to Settings")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            
                            Text("Go to Settings > Accessibility > Spoken Content > Voices > English > Voice and download enhanced voices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
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
                
                // Auto-select first voice if there are voices but none selected
                if voiceSettings.selectedVoiceIdentifier == nil && !voiceSettings.availableVoices.isEmpty {
                    voiceSettings.selectedVoiceIdentifier = voiceSettings.availableVoices[0].identifier
                }
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
    @State private var isListeningMode = false
    @State private var hasPlayedWelcomeMessage = false
    
    // For visual animation of listening mode
    @State private var listeningAnimation = false
    
    // For silence detection
    @State private var silenceTimer: Timer? = nil
    private let silenceDuration: TimeInterval = 1.5 // Seconds of silence before ending listening mode
    
    // Add callback for returning to setup screen
    var onReturnToSetup: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack {
                // Header with call sign and settings button
                HStack {
                    if let callSign = towerController.userVehicle?.callSign {
                        Text("Call Sign: \(callSign)")
                            .font(.title2)
                            .padding()
                            .background(isListeningMode ? 
                                Color.blue.opacity(listeningAnimation ? 0.6 : 0.3) : 
                                Color.blue.opacity(0.2))
                            .cornerRadius(10)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: listeningAnimation)
                    }
                    
                    Spacer()
                    
                    // Back button to return to setup
                    if onReturnToSetup != nil {
                        Button(action: {
                            onReturnToSetup?()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(10)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
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
                
                // Listening mode indicator
                if isListeningMode {
                    listeningModeView
                        .transition(.opacity)
                        .animation(.easeInOut, value: isListeningMode)
                }
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
        .onChange(of: speechService.isSpeaking) { isSpeaking in
            // When tower stops speaking, check if it was the welcome message
            if !isSpeaking && !hasPlayedWelcomeMessage && towerController.towerMessages.count == 1 {
                // This is the welcome message finishing
                hasPlayedWelcomeMessage = true
                
                // Start listening mode after a brief pause to allow the welcome message to sink in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startListeningMode()
                }
            }
        }
        .onChange(of: speechService.recognizedText) { text in
            if isListeningMode, let callSign = towerController.userVehicle?.callSign {
                // Reset the silence timer whenever we get new text
                silenceTimer?.invalidate()
                
                if !text.isEmpty {
                    // Start a new silence timer to detect when the user stops speaking
                    silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDuration, repeats: false) { _ in
                        // User has been silent for the duration
                        if !text.isEmpty {
                            endListeningMode()
                            
                            // Process the user's message and continue the communication loop
                            towerController.processListeningLoop(userText: text, callSign: callSign)
                        }
                    }
                }
            }
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
                    Text("\(locationService.currentStreet)")
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
                } else if isListeningMode {
                    Text("Listening Mode Active")
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                        .opacity(listeningAnimation ? 1.0 : 0.7)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: listeningAnimation)
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
        .background(isListeningMode ? 
            (colorScheme == .dark ? Color.blue.opacity(0.25) : Color.blue.opacity(0.1)) : 
            (colorScheme == .dark ? Color.black : Color.white))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // Listening mode view with microphone icon
    private var listeningModeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(listeningAnimation ? 0.3 : 0.1))
                        .frame(width: 120, height: 120)
                )
                .scaleEffect(listeningAnimation ? 1.1 : 1.0)
                
            Text("LISTENING MODE")
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.bottom, 5)
                
            Text("Speak clearly when ready")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            if let callSign = towerController.userVehicle?.callSign {
                Text("Tower will respond after you finish speaking")
                    .font(.callout)
                    .foregroundColor(.primary)
                    .padding(.top, 5)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
    }
    
    // Function to start listening mode
    private func startListeningMode() {
        // Start the animation
        listeningAnimation = true
        
        // Start the speech recognition
        speechService.startListening()
        
        // Set the state
        isListeningMode = true
    }
    
    // Function to end listening mode
    private func endListeningMode() {
        // Stop the speech recognition
        speechService.stopListening()
        
        // Stop any pending silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Set the state
        isListeningMode = false
        listeningAnimation = false
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
