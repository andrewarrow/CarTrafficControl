import Foundation
import CoreLocation
import Combine

class TowerController: ObservableObject {
    private let speechService: SpeechService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    @Published var userVehicle: UserVehicle?
    @Published var towerMessages: [String] = []
    @Published var userMessages: [String] = []
    @Published var isCommunicationValid = false
    @Published var isRefreshing = false
    
    init(speechService: SpeechService, locationService: LocationService) {
        self.speechService = speechService
        self.locationService = locationService
        
        // Monitor speech recognition
        speechService.$recognizedText
            .filter { !$0.isEmpty }
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.processUserSpeech(text)
            }
            .store(in: &cancellables)
        
        // Monitor location changes
        locationService.$currentStreet
            .combineLatest(locationService.$currentCrossStreet)
            .debounce(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] street, crossStreet in
                guard let self = self, let callSign = self.userVehicle?.callSign else { return }
                self.generateLocationBasedMessage(street: street, crossStreet: crossStreet, callSign: callSign)
            }
            .store(in: &cancellables)
    }
    
    func setUserVehicle(make: CarMake, licensePlateDigits: String) {
        userVehicle = UserVehicle(make: make, licensePlateDigits: licensePlateDigits)
        
        // Get ready for the welcome message with location
        if let callSign = userVehicle?.callSign {
            // Wait briefly to allow location service to get street information
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.sendWelcomeMessage(callSign: callSign)
            }
            
            // Disable location-based messages for the initial period
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.enableLocationBasedMessages()
            }
        }
    }
    
    private func sendWelcomeMessage(callSign: String) {
        // Get current street information
        let street = formatStreetForSpeech(locationService.currentStreet)
        let crossStreet = formatStreetForSpeech(locationService.currentCrossStreet)
        
        // Create personalized welcome message with location
        let welcomeMessage: String
        
        if street != "unknown street" {
            // Simplified welcome message with just the street name
            welcomeMessage = "\(callSign) approach end of \(street) and hold."
        } else {
            // Fallback if no location data is available
            welcomeMessage = "\(callSign) maintain position."
        }
        
        // Send and speak the welcome message
        addTowerMessage(welcomeMessage)
        speechService.speak(welcomeMessage, withCallSign: callSign)
    }
    
    // Format street names for better speech synthesis
    private func formatStreetForSpeech(_ street: String) -> String {
        // Replace "&" with "and" for better pronunciation
        var formatted = street.replacingOccurrences(of: "&", with: "and")
        
        // Convert abbreviations to full names for better pronunciation
        // With periods
        formatted = formatted.replacingOccurrences(of: "St.", with: "Street")
        formatted = formatted.replacingOccurrences(of: "Ave.", with: "Avenue")
        formatted = formatted.replacingOccurrences(of: "Rd.", with: "Road")
        formatted = formatted.replacingOccurrences(of: "Blvd.", with: "Boulevard")
        formatted = formatted.replacingOccurrences(of: "Dr.", with: "Drive")
        formatted = formatted.replacingOccurrences(of: "Ln.", with: "Lane")
        formatted = formatted.replacingOccurrences(of: "Ct.", with: "Court")
        formatted = formatted.replacingOccurrences(of: "Pl.", with: "Place")
        formatted = formatted.replacingOccurrences(of: "Pkwy.", with: "Parkway")
        formatted = formatted.replacingOccurrences(of: "Cir.", with: "Circle")
        formatted = formatted.replacingOccurrences(of: "Ter.", with: "Terrace")
        formatted = formatted.replacingOccurrences(of: "Hwy.", with: "Highway")
        
        // Without periods (matching word boundaries to avoid partial matches)
        let wordBoundary = "\\b"
        formatted = formatted.replacingOccurrences(of: wordBoundary + "St" + wordBoundary, with: "Street", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Ave" + wordBoundary, with: "Avenue", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Rd" + wordBoundary, with: "Road", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Blvd" + wordBoundary, with: "Boulevard", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Dr" + wordBoundary, with: "Drive", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Ln" + wordBoundary, with: "Lane", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Ct" + wordBoundary, with: "Court", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Pl" + wordBoundary, with: "Place", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Pkwy" + wordBoundary, with: "Parkway", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Cir" + wordBoundary, with: "Circle", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Ter" + wordBoundary, with: "Terrace", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: wordBoundary + "Hwy" + wordBoundary, with: "Highway", options: .regularExpression)
        
        return formatted
    }
    
    // Temporarily disable location-based messages
    private var locationBasedMessagesEnabled = false
    
    private func enableLocationBasedMessages() {
        locationBasedMessagesEnabled = true
    }
    
    private func processUserSpeech(_ text: String) {
        // Add to user messages
        addUserMessage(text)
        
        // Check if communication starts and ends with callsign
        guard let callSign = userVehicle?.callSign else { return }
        
        let normalizedText = text.uppercased()
        let hasProperFormat = normalizedText.hasPrefix(callSign) && normalizedText.hasSuffix(callSign)
        
        isCommunicationValid = hasProperFormat
        
        // Generate response if valid
        if hasProperFormat {
            generateResponse(to: text, callSign: callSign)
        } else {
            let correctionMessage = "\(callSign), please begin and end your communication with your call sign."
            addTowerMessage(correctionMessage)
            speechService.speak(correctionMessage, withCallSign: callSign)
        }
    }
    
    private func generateResponse(to message: String, callSign: String) {
        // Very simple random response generator
        let randomResponses = [
            "\(callSign), roger that. Continue on current route and maintain speed.",
            "\(callSign), copy that. Watch for traffic merging from your right.",
            "\(callSign), message received. Be advised of construction ahead. Reduce speed.",
            "\(callSign), affirmative. You're cleared to proceed through next intersection.",
            "\(callSign), acknowledged. Hold position at next stop sign."
        ]
        
        let response = randomResponses.randomElement() ?? "\(callSign), message acknowledged."
        addTowerMessage(response)
        speechService.speak(response, withCallSign: callSign)
    }
    
    private func generateLocationBasedMessage(street: String, crossStreet: String, callSign: String) {
        // Skip if location-based messages are disabled
        guard locationBasedMessagesEnabled else {
            print("Location-based messages currently disabled")
            return
        }
        
        // Format street names for better speech
        let formattedStreet = formatStreetForSpeech(street)
        
        // Using shorter message format with just the street name
        let message = "\(callSign) approach end of \(formattedStreet) and hold."
        
        addTowerMessage(message)
        speechService.speak(message, withCallSign: callSign)
    }
    
    private func addTowerMessage(_ message: String) {
        DispatchQueue.main.async {
            self.towerMessages.append(message)
        }
    }
    
    private func addUserMessage(_ message: String) {
        DispatchQueue.main.async {
            self.userMessages.append(message)
        }
    }
    
    // Function to manually request a new tower message - used for pull-to-refresh
    func requestNewTowerMessage() async {
        guard let callSign = userVehicle?.callSign else { return }
        
        DispatchQueue.main.async {
            self.isRefreshing = true
        }
        
        // Get current location
        await withCheckedContinuation { continuation in
            // Request updated location
            self.locationService.startLocationUpdates()
            
            // Wait briefly for location to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Generate a new message based on current location
                let street = self.formatStreetForSpeech(self.locationService.currentStreet)
                let crossStreet = self.formatStreetForSpeech(self.locationService.currentCrossStreet)
                
                // Create a message with some variety
                let randomMessages = [
                    "\(callSign) approach end of \(street) and hold.",
                    "\(callSign) proceed with caution on \(street).",
                    "\(callSign) maintain current position on \(street).",
                    "\(callSign) watch for traffic ahead on \(street).",
                    "\(callSign) reduce speed on \(street)."
                ]
                
                let message = randomMessages.randomElement() ?? "\(callSign) proceed on \(street)."
                
                // Add the new message without clearing previous ones
                DispatchQueue.main.async {
                    self.addTowerMessage(message)
                    self.speechService.speak(message, withCallSign: callSign)
                    self.isRefreshing = false
                    continuation.resume()
                }
            }
        }
    }
    
    // Function that handles the listen-speak loop
    // Called by MainView when the user has completed a listening cycle
    func processListeningLoop(userText: String, callSign: String) {
        // Add user message
        addUserMessage(userText)
        
        // Check for call sign in the message (already done in MainView)
        let hasCallSign = userText.uppercased().contains(callSign)
        
        if hasCallSign {
            // Prepare response after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task {
                    await self.requestNewTowerMessage()
                }
            }
        }
    }
}