import SwiftUI

struct MainView: View {
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var towerController: TowerController
    
    // Add callback for returning to setup screen
    var onReturnToSetup: (() -> Void)?
    
    var body: some View {
        VStack {
            // Header with call sign and back button
            HStack {
                if let callSign = towerController.userVehicle?.callSign {
                    Text("Call Sign: \(callSign)")
                        .font(.title2)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)
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
            }
            
            // Current location display
            locationInfoView
            
            // Tower messages
            messageListView
            
            // Voice recording controls
            controlsView
        }
        .padding()
        .onAppear {
            locationService.startLocationUpdates()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
            speechService.stopListening()
        }
    }
    
    private var locationInfoView: some View {
        VStack(alignment: .leading) {
            Text("Current Location:")
                .font(.headline)
            
            HStack {
                Image(systemName: "location.fill")
                Text("\(locationService.currentStreet) & \(locationService.currentCrossStreet)")
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var messageListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lastTowerMessage = towerController.towerMessages.last {
                MessageBubbleView(message: lastTowerMessage, isFromTower: true)
            }
            
            if let lastUserMessage = towerController.userMessages.last {
                MessageBubbleView(message: lastUserMessage, isFromTower: false)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text(speechService.isListening ? "Listening..." : "Press to Speak")
                    .font(.headline)
                    .foregroundColor(speechService.isListening ? .green : .primary)
                
                Spacer()
                
                if speechService.isSpeaking {
                    Text("Tower Speaking...")
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
            }
            
            HStack {
                Button(action: {
                    if speechService.isListening {
                        speechService.stopListening()
                    } else {
                        speechService.startListening()
                    }
                }) {
                    HStack {
                        Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                        Text(speechService.isListening ? "Stop" : "Start")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(speechService.isListening ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(speechService.isSpeaking)
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
        .background(Color.white)
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