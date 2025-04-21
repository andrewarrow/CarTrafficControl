# CTC (Car Traffic Control)

An iOS application that simulates the experience of Air Traffic Control (ATC) for drivers. This app creates a two-way voice communication system between drivers and a simulated "tower" control, mimicking the structured communication protocols used in aviation.

## Features

- **Call Sign System**: Users create a unique call sign based on their car make and license plate digits (e.g., HONDA747, JEEP901)
- **Voice Interaction**: Uses iOS Speech-to-Text to listen to driver's communications and Text-to-Speech to deliver tower messages
- **Location Awareness**: Uses iOS Location Services to track current streets and intersections
- **Radio-Style Communication**: Simulates the format and style of aviation communication
- **Real-time Feedback**: Verifies proper use of call signs at beginning and end of communications

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Physical iOS device (for optimal speech recognition and location services)

## Permissions Required

- Microphone access for speech recognition
- Location services for street tracking

## Usage

1. At first launch, the app will request necessary permissions
2. Select your car make from the dropdown menu
3. Enter the last few digits of your license plate
4. Start driving and the tower will begin communicating with you
5. To respond, tap the microphone button and speak
6. Always begin and end your messages with your call sign (e.g., "HONDA747 approaching Main Street HONDA747")

## Development

This project uses:
- SwiftUI for the user interface
- Combine for reactive programming
- CoreLocation for GPS and street detection
- Speech framework for voice recognition
- AVFoundation for text-to-speech

## License

Private - All rights reserved.

## Disclaimer

This app is intended for entertainment purposes only. Always prioritize safe driving practices and follow all applicable traffic laws and regulations. Do not use this app in a way that distracts from safe driving.