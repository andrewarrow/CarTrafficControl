import SwiftUI

@main
struct CarTrafficControlApp: App {
    // App lifecycle state observer
    @StateObject private var lifecycleManager = AppLifecycleManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Pass the lifecycle manager to the content view
                .environmentObject(lifecycleManager)
        }
    }
}

// Class to manage app lifecycle and cleanup
class AppLifecycleManager: ObservableObject {
    // Called by views that need to register for cleanup
    var speechService: SpeechService?
    
    init() {
        // Set up notification observers for app lifecycle events
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        print("AppLifecycleManager: Initialized and monitoring app lifecycle events")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // App is about to go to the background
    @objc private func appWillResignActive() {
        print("AppLifecycleManager: App will resign active")
        performCleanup()
    }
    
    // App did enter background
    @objc private func appDidEnterBackground() {
        print("AppLifecycleManager: App did enter background")
        performCleanup()
    }
    
    // App will terminate
    @objc private func appWillTerminate() {
        print("AppLifecycleManager: App will terminate")
        performCleanup()
    }
    
    // Central cleanup method
    private func performCleanup() {
        print("AppLifecycleManager: Performing cleanup...")
        
        // Clean up speech service
        speechService?.cleanup()
        
        print("AppLifecycleManager: Cleanup complete")
    }
    
    // Register services for cleanup
    func register(speechService: SpeechService) {
        self.speechService = speechService
        print("AppLifecycleManager: Registered SpeechService for cleanup")
    }
}