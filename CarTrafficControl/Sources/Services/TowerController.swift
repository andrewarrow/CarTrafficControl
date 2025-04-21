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
        
        // Welcome message
        if let callSign = userVehicle?.callSign {
            let welcomeMessage = "\(callSign), Car Traffic Control tower now tracking your vehicle. Maintain current speed and report at next intersection. Tower out."
            addTowerMessage(welcomeMessage)
            speechService.speak(welcomeMessage, withCallSign: callSign)
        }
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
        // Generate location-specific message
        let scenarios = [
            "\(callSign), we show you approaching \(street) and \(crossStreet). Proceed with caution. Tower out.",
            "\(callSign), you are currently on \(street) near \(crossStreet). Be advised of heavy traffic ahead. Tower out.",
            "\(callSign), traffic control shows you at \(street) and \(crossStreet). Hold at next signal. Tower out.",
            "\(callSign), radar indicates you're traveling on \(street). Proceed to \(crossStreet) and wait for further instructions. Tower out."
        ]
        
        let message = scenarios.randomElement() ?? "\(callSign), we have you on \(street). Continue as planned. Tower out."
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
}