import Foundation
import CoreLocation

public class CompassService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published public var heading: Double = 0.0
    @Published public var isCalibrating: Bool = false
    
    public override init() {
        super.init()
        locationManager.delegate = self
        
        // Check if device has heading capability
        if CLLocationManager.headingAvailable() {
            startUpdatingHeading()
        }
    }
    
    public func startUpdatingHeading() {
        locationManager.startUpdatingHeading()
    }
    
    public func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use true heading if available (relative to true north), fallback to magnetic heading
        let headingValue = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        // Update the published heading value
        heading = headingValue
        
        // Reset calibration flag when we get valid readings
        if isCalibrating && newHeading.headingAccuracy >= 0 {
            isCalibrating = false
        }
    }
    
    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Return true to allow the system to display the heading calibration UI if needed
        isCalibrating = true
        return true
    }
}