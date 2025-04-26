import Foundation

struct CarMake: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

let popularCarMakes: [CarMake] = [
    CarMake(name: "Select"),
    CarMake(name: "Abarth"),
    CarMake(name: "Acura"),
    CarMake(name: "Alfa Romeo"),
    CarMake(name: "Alpine"),
    CarMake(name: "Apollo"),
    CarMake(name: "Ariel"),
    CarMake(name: "Ascari"),
    CarMake(name: "Aston Martin"),
    CarMake(name: "Audi"),
    CarMake(name: "BAC"),
    CarMake(name: "BAIC"),
    CarMake(name: "Baojun"),
    CarMake(name: "Bentley"),
    CarMake(name: "BMW"),
    CarMake(name: "Borgward"),
    CarMake(name: "Bugatti"),
    CarMake(name: "Buick"),
    CarMake(name: "BYD"),
    CarMake(name: "Cadillac"),
    CarMake(name: "Caterham"),
    CarMake(name: "Chang'an"),
    CarMake(name: "Chery"),
    CarMake(name: "Chevrolet"),
    CarMake(name: "Chrysler"),
    CarMake(name: "Citroën"),
    CarMake(name: "Dacia"),
    CarMake(name: "Daewoo"),
    CarMake(name: "Daihatsu"),
    CarMake(name: "Datsun"),
    CarMake(name: "DeLorean"),
    CarMake(name: "De Tomaso"),
    CarMake(name: "Dodge"),
    CarMake(name: "Dongfeng"),
    CarMake(name: "DS"),
    CarMake(name: "Eagle"),
    CarMake(name: "Faraday Future"),
    CarMake(name: "Ferrari"),
    CarMake(name: "Fiat"),
    CarMake(name: "Fisker"),
    CarMake(name: "Ford"),
    CarMake(name: "Foton"),
    CarMake(name: "GAC"),
    CarMake(name: "Geely"),
    CarMake(name: "Genesis"),
    CarMake(name: "GMC"),
    CarMake(name: "Great Wall"),
    CarMake(name: "Haval"),
    CarMake(name: "Hennessey"),
    CarMake(name: "Holden"),
    CarMake(name: "Honda"),
    CarMake(name: "Hongqi"),
    CarMake(name: "Hummer"),
    CarMake(name: "Hupmobile"),
    CarMake(name: "Hyundai"),
    CarMake(name: "Infiniti"),
    CarMake(name: "Isuzu"),
    CarMake(name: "Jaguar"),
    CarMake(name: "Jeep"),
    CarMake(name: "Kia"),
    CarMake(name: "Koenigsegg"),
    CarMake(name: "Lada"),
    CarMake(name: "Lamborghini"),
    CarMake(name: "Lancia"),
    CarMake(name: "Land Rover"),
    CarMake(name: "Landwind"),
    CarMake(name: "Lexus"),
    CarMake(name: "Lincoln"),
    CarMake(name: "Lotus"),
    CarMake(name: "Lucid"),
    CarMake(name: "Lynk & Co"),
    CarMake(name: "Mahindra"),
    CarMake(name: "Maserati"),
    CarMake(name: "Maybach"),
    CarMake(name: "Mazda"),
    CarMake(name: "McLaren"),
    CarMake(name: "Mercedes"),
    CarMake(name: "Mercury"),
    CarMake(name: "MG"),
    CarMake(name: "Mini"),
    CarMake(name: "Mitsubishi"),
    CarMake(name: "Morgan"),
    CarMake(name: "NIO"),
    CarMake(name: "Nissan"),
    CarMake(name: "Noble"),
    CarMake(name: "Oldsmobile"),
    CarMake(name: "Opel"),
    CarMake(name: "Packard"),
    CarMake(name: "Pagani"),
    CarMake(name: "Panoz"),
    CarMake(name: "Peugeot"),
    CarMake(name: "Plymouth"),
    CarMake(name: "Polestar"),
    CarMake(name: "Pontiac"),
    CarMake(name: "Porsche"),
    CarMake(name: "Proton"),
    CarMake(name: "Ram"),
    CarMake(name: "Renault"),
    CarMake(name: "Rimac"),
    CarMake(name: "Rivian"),
    CarMake(name: "Rolls Royce"),
    CarMake(name: "Saab"),
    CarMake(name: "Saturn"),
    CarMake(name: "Scion"),
    CarMake(name: "Seat"),
    CarMake(name: "Škoda"),
    CarMake(name: "Smart"),
    CarMake(name: "Subaru"),
    CarMake(name: "Suzuki"),
    CarMake(name: "Tesla"),
    CarMake(name: "Toyota"),
    CarMake(name: "Vauxhall"),
    CarMake(name: "Volkswagen"),
    CarMake(name: "Volvo"),
    CarMake(name: "Wuling")
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