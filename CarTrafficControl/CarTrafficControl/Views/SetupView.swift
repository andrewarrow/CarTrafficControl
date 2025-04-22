import SwiftUI

struct SetupView: View {
    @EnvironmentObject var towerController: TowerController
    
    // Set Kia as default car make and 2703 as default license plate
    @State private var selectedCarMake: CarMake? = popularCarMakes.first(where: { $0.name == "Kia" })
    @State private var licensePlateDigits = "2703"
    
    var onSetupComplete: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Information")) {
                    Picker("Car Make", selection: $selectedCarMake) {
                        Text("Select a car make").tag(nil as CarMake?)
                        ForEach(popularCarMakes) { make in
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
                        if let make = selectedCarMake, !licensePlateDigits.isEmpty {
                            towerController.setUserVehicle(make: make, licensePlateDigits: licensePlateDigits)
                            onSetupComplete()
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
        }
    }
    
    private func requestPermissions() {
        // This would be replaced by proper permission handling in a real app
        let speechService = SpeechService()
        let locationService = LocationService()
        
        speechService.requestSpeechRecognitionPermission()
        locationService.requestLocationPermission()
    }
}