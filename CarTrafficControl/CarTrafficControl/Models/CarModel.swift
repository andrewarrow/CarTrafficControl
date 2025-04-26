import Foundation

struct CarMake: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

let popularCarMakes: [CarMake] = [
    CarMake(name: "Honda"),
    CarMake(name: "Toyota"),
    CarMake(name: "Ford"),
    CarMake(name: "Chevrolet"),
    CarMake(name: "Jeep"),
    CarMake(name: "BMW"),
    CarMake(name: "Mercedes"),
    CarMake(name: "Audi"),
    CarMake(name: "Tesla"),
    CarMake(name: "Subaru"),
    CarMake(name: "Nissan"),
    CarMake(name: "Hyundai"),
    CarMake(name: "Kia"),
    CarMake(name: "Lexus"),
    CarMake(name: "Mazda")
]

struct UserVehicle {
    let make: CarMake
    let licensePlateDigits: String
    
    var callSign: String {
        return "\(make.name.uppercased())\(licensePlateDigits)"
    }
    
    // Add UserDefaults keys
    static let makeKey = "savedCarMake"
    static let licensePlateKey = "savedLicensePlate"
    
    // Save to UserDefaults
    func saveToUserDefaults() {
        UserDefaults.standard.set(make.name, forKey: UserVehicle.makeKey)
        UserDefaults.standard.set(licensePlateDigits, forKey: UserVehicle.licensePlateKey)
    }
    
    // Load from UserDefaults
    static func loadFromUserDefaults() -> UserVehicle? {
        guard let savedMakeName = UserDefaults.standard.string(forKey: makeKey),
              let carMake = popularCarMakes.first(where: { $0.name == savedMakeName }),
              let licensePlate = UserDefaults.standard.string(forKey: licensePlateKey),
              !licensePlate.isEmpty else {
            return nil
        }
        
        return UserVehicle(make: carMake, licensePlateDigits: licensePlate)
    }
}