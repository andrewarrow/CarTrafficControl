import Foundation
import CoreLocation
import MapKit

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var currentLocation: CLLocation?
    @Published var currentStreet: String = "unknown street"
    @Published var currentCrossStreet: String = "unknown intersection"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update location every 10 meters
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        // Request a fresh location update
        locationManager.requestLocation()
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if manager.authorizationStatus == .authorizedWhenInUse || 
           manager.authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Get street names using both methods
        reverseGeocodePrimaryStreet(location)
        searchForIntersectingStreets(location)
    }
    
    // Function to get primary street name through reverse geocoding
    private func reverseGeocodePrimaryStreet(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, error == nil, let placemark = placemarks?.first else { return }
            
            if let thoroughfare = placemark.thoroughfare {
                self.currentStreet = thoroughfare
            }
        }
    }
    
    // Function to search for better intersection names
    private func searchForIntersectingStreets(_ location: CLLocation) {
        // Primary search for intersections
        findIntersections(near: location, searchTerm: "intersection", radius: 200)
        
        // If main search doesn't yield good results within 2 seconds, try nearby streets
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            if !self.hasValidCrossStreet() {
                self.findIntersections(near: location, searchTerm: "street", radius: 300)
            }
        }
        
        // Last resort - clear the "Intersection" text if we couldn't find a proper name
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self else { return }
            if !self.hasValidCrossStreet() {
                // Clear invalid intersection names
                self.currentCrossStreet = ""
            }
        }
    }
    
    // Check if we have a valid cross street name
    private func hasValidCrossStreet() -> Bool {
        let lowQualityNames = ["unknown intersection", "Intersection", "Intersections La", "& Intersection"]
        
        // Clean the cross street name if it contains "& Intersection" or similar patterns
        if currentCrossStreet.contains("&") {
            // Check for patterns like "Main St & Intersection X"
            let components = currentCrossStreet.components(separatedBy: "&")
            if components.count > 0 {
                // If the first part is valid, use just that part
                let firstPart = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if !firstPart.isEmpty && !lowQualityNames.contains(firstPart) {
                    currentCrossStreet = ""
                    return false
                }
                
                // Otherwise, check if any part after "& Intersection" has a valid name
                for i in 1..<components.count {
                    let part = components[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !part.lowercased().contains("intersection") && !part.isEmpty {
                        currentCrossStreet = part
                        return true
                    }
                }
                
                // If we get here, we didn't find a good name in any part
                currentCrossStreet = ""
                return false
            }
        }
        
        // Check if the name contains "Intersection" but isn't just "Intersection"
        if currentCrossStreet.lowercased().contains("intersection") {
            // If it's a generic intersection name, clear it
            currentCrossStreet = ""
            return false
        }
        
        return !lowQualityNames.contains(currentCrossStreet) && !currentCrossStreet.isEmpty
    }
    
    // Function to search for intersections with different parameters
    private func findIntersections(near location: CLLocation, searchTerm: String, radius: Double) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchTerm
        searchRequest.region = MKCoordinateRegion(center: location.coordinate,
                                                  latitudinalMeters: radius,
                                                  longitudinalMeters: radius)
        
        // Only look for streets/roads, not POIs or businesses
        searchRequest.resultTypes = .address
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] response, error in
            guard let self = self, error == nil, let response = response else { return }
            
            // Find a nearby street with a proper name that's different from current street
            for item in response.mapItems {
                if let name = item.name, 
                   name != self.currentStreet &&
                   !name.isEmpty {
                    
                    // Skip if this is clearly a POI and not a street
                    if isProbablyPOI(name) {
                        continue
                    }
                    
                    // If it contains "Intersection", we'll skip it
                    if name.lowercased().contains("intersection") {
                        continue
                    }
                    
                    // If it contains "&", extract the most meaningful part
                    if name.contains("&") {
                        let components = name.components(separatedBy: "&")
                        
                        // Try to find a component that looks like a street name
                        var bestComponent = ""
                        for component in components {
                            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && 
                               !trimmed.lowercased().contains("intersection") &&
                               isLikelyStreetName(trimmed) {
                                bestComponent = trimmed
                                break
                            }
                        }
                        
                        // If we found a good component, use it
                        if !bestComponent.isEmpty {
                            self.currentCrossStreet = bestComponent
                            break
                        }
                        
                        // Otherwise continue looking for better names
                        continue
                    }
                    
                    // Only use if it's likely a street name
                    if isLikelyStreetName(name) {
                        self.currentCrossStreet = name
                        break
                    }
                }
            }
            
            // After we've processed all responses, check if we have a valid cross street
            if !self.hasValidCrossStreet() {
                // If not, clear it - we'll fall back to using just the main street
                self.currentCrossStreet = ""
            }
        }
    }
    
    // Helper to filter out business names and POIs
    private func isProbablyPOI(_ name: String) -> Bool {
        let poiKeywords = [
            "office", "construction", "store", "mall", "restaurant", "cafe", 
            "building", "center", "centre", "plaza", "complex", "shop", "studio",
            "bank", "hospital", "school", "university", "college", "institute",
            "church", "temple", "mosque", "library", "museum", "theater", "theatre",
            "park", "garden", "hotel", "motel", "inn", "apartment", "residence"
        ]
        
        let lowercaseName = name.lowercased()
        return poiKeywords.contains { lowercaseName.contains($0) }
    }
    
    // Check if a name is likely a street
    private func isLikelyStreetName(_ name: String) -> Bool {
        let streetSuffixes = [
            "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd",
            "lane", "ln", "drive", "dr", "way", "circle", "cir", "court", "ct",
            "place", "pl", "terrace", "ter", "highway", "hwy", "freeway", "fwy",
            "parkway", "pkwy", "alley", "route", "rt"
        ]
        
        let lowercaseName = name.lowercased()
        
        // Check for street suffixes
        for suffix in streetSuffixes {
            if lowercaseName.contains(" " + suffix) || lowercaseName.hasSuffix(" " + suffix) {
                return true
            }
        }
        
        // Check for numbered streets like "5th Street" or "3rd Ave"
        let numberPattern = #"^\d+(st|nd|rd|th)\s"#
        if lowercaseName.range(of: numberPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Check for cardinal directions which often appear in street names
        let directions = ["north", "south", "east", "west", "n.", "s.", "e.", "w."]
        for direction in directions {
            if lowercaseName.contains(direction + " ") || lowercaseName.hasPrefix(direction + " ") {
                return true
            }
        }
        
        return false
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors but don't interrupt app flow
        print("Location error: \(error.localizedDescription)")
        
        // If the error is from requestLocation(), we still have continuous updates from startUpdatingLocation()
        if (error as NSError).domain == kCLErrorDomain {
            if (error as NSError).code == CLError.locationUnknown.rawValue {
                // This is a temporary error that might be resolved shortly - no need to show to user
                print("Location currently unknown but might resolve soon")
            } else {
                // Other location errors - continue with last known location
                print("Location error: \(error.localizedDescription), continuing with last known location")
            }
        }
    }
}