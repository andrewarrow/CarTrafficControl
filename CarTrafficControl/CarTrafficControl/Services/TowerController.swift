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
        
        if street != "unknown street" && !crossStreet.isEmpty && 
           crossStreet != "unknown intersection" && crossStreet != "Intersection" && 
           crossStreet != "Intersections La" && !crossStreet.contains("& Intersection") {
            // We have two good street names
            welcomeMessage = "\(callSign), Car Traffic Control tower now tracking your vehicle at \(street) and \(crossStreet). Maintain current speed and proceed with caution. Tower out."
        } else if street != "unknown street" {
            // We have at least the main street
            welcomeMessage = "\(callSign), Car Traffic Control tower now tracking your vehicle on \(street). Maintain current speed and report at next intersection. Tower out."
        } else {
            // Fallback if no location data is available
            welcomeMessage = "\(callSign), Car Traffic Control tower now tracking your vehicle. Maintain current speed and report at next intersection. Tower out."
        }
        
        // Send and speak the welcome message
        addTowerMessage(welcomeMessage)
        speechService.speak(welcomeMessage, withCallSign: callSign)
    }
    
    // Format street names for better speech synthesis
    private func formatStreetForSpeech(_ street: String) -> String {
        // Replace "&" with "and" for better pronunciation
        var formatted = street.replacingOccurrences(of: "&", with: "and")
        
        // Other potential speech improvements
        formatted = formatted.replacingOccurrences(of: "St.", with: "Street")
        formatted = formatted.replacingOccurrences(of: "Ave.", with: "Avenue")
        formatted = formatted.replacingOccurrences(of: "Rd.", with: "Road")
        formatted = formatted.replacingOccurrences(of: "Blvd.", with: "Boulevard")
        formatted = formatted.replacingOccurrences(of: "Dr.", with: "Drive")
        
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
            let correctionMessage = "\(callSign), please begin and end your communication with your call sign. Tower out."
            addTowerMessage(correctionMessage)
            speechService.speak(correctionMessage, withCallSign: callSign)
        }
    }
    
    private func generateResponse(to message: String, callSign: String) {
        // Very simple random response generator
        let randomResponses = [
            "\(callSign), roger that. Continue on current route and maintain speed. Tower out.",
            "\(callSign), copy that. Watch for traffic merging from your right. Tower out.",
            "\(callSign), message received. Be advised of construction ahead. Reduce speed. Tower out.",
            "\(callSign), affirmative. You're cleared to proceed through next intersection. Tower out.",
            "\(callSign), acknowledged. Hold position at next stop sign. Tower out."
        ]
        
        let response = randomResponses.randomElement() ?? "\(callSign), message acknowledged. Tower out."
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
        let formattedCrossStreet = formatStreetForSpeech(crossStreet)
        
        // Determine if we have valid cross street data
        let hasValidCrossStreet = !formattedCrossStreet.isEmpty && 
                                  formattedCrossStreet != "unknown intersection" && 
                                  formattedCrossStreet != "Intersection" && 
                                  formattedCrossStreet != "Intersections La" &&
                                  !formattedCrossStreet.contains("and Intersection")
        
        // Generate location-specific message based on available data
        let message: String
        
        if hasValidCrossStreet {
            // We have two valid street names - use more specific messaging
            let scenariosWithBothStreets = [
                "\(callSign), we show you approaching \(formattedStreet) and \(formattedCrossStreet). Proceed with caution. Tower out.",
                "\(callSign), you are currently on \(formattedStreet) near \(formattedCrossStreet). Be advised of heavy traffic ahead. Tower out.",
                "\(callSign), traffic control shows you at \(formattedStreet) and \(formattedCrossStreet). Hold at next signal. Tower out.",
                "\(callSign), radar indicates you're at the intersection of \(formattedStreet) and \(formattedCrossStreet). Proceed with caution. Tower out."
            ]
            message = scenariosWithBothStreets.randomElement() ?? "\(callSign), we have you at \(formattedStreet) and \(formattedCrossStreet). Continue as planned. Tower out."
        } else {
            // We only have the main street - use more generic messaging
            let scenariosWithOneStreet = [
                "\(callSign), we show you traveling on \(formattedStreet). Proceed with caution. Tower out.",
                "\(callSign), you are currently on \(formattedStreet). Be advised of heavy traffic ahead. Tower out.",
                "\(callSign), traffic control shows you on \(formattedStreet). Hold at next signal. Tower out.",
                "\(callSign), radar indicates you're traveling on \(formattedStreet). Continue and report at next intersection. Tower out."
            ]
            message = scenariosWithOneStreet.randomElement() ?? "\(callSign), we have you on \(formattedStreet). Continue as planned. Tower out."
        }
        
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
                
                // Create a special status update message
                let hasValidCrossStreet = !crossStreet.isEmpty && 
                                        crossStreet != "unknown intersection" && 
                                        crossStreet != "Intersection" && 
                                        crossStreet != "Intersections La" &&
                                        !crossStreet.contains("and Intersection")
                
                let message: String
                if hasValidCrossStreet {
                    message = "\(callSign), status update requested. Your position is confirmed at \(street) and \(crossStreet). Continue on current heading. Tower out."
                } else {
                    message = "\(callSign), status update requested. Your position is confirmed on \(street). Continue on current heading. Tower out."
                }
                
                // Clear previous tower messages and add the new one
                DispatchQueue.main.async {
                    self.towerMessages.removeAll()
                    self.addTowerMessage(message)
                    self.speechService.speak(message, withCallSign: callSign)
                    self.isRefreshing = false
                    continuation.resume()
                }
            }
        }
    }
}