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
}