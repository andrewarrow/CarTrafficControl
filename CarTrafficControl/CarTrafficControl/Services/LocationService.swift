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
        
        // Reverse geocode to get street names
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, error == nil, let placemark = placemarks?.first else { return }
            
            if let thoroughfare = placemark.thoroughfare {
                self.currentStreet = thoroughfare
            }
            
            // Get nearby streets for intersection
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = "intersection"
            searchRequest.region = MKCoordinateRegion(center: location.coordinate, 
                                                      latitudinalMeters: 200, 
                                                      longitudinalMeters: 200)
            
            let search = MKLocalSearch(request: searchRequest)
            search.start { response, error in
                guard error == nil, let response = response else { return }
                
                // Extract the first result that could be a cross street
                if let item = response.mapItems.first(where: { $0.name != self.currentStreet }),
                   let crossStreet = item.name {
                    self.currentCrossStreet = crossStreet
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}