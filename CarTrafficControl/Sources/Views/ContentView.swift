import SwiftUI

struct ContentView: View {
    @StateObject private var speechService = SpeechService()
    @StateObject private var locationService = LocationService()
    @StateObject private var towerController: TowerController
    
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
        } else {
            SetupView(onSetupComplete: {
                isSetupComplete = true
            })
            .environmentObject(towerController)
        }
    }
}