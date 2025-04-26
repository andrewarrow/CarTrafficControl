import SwiftUI

public struct CompassView: View {
    @EnvironmentObject var compassService: CompassService
    
    public init() {}
    
    public var body: some View {
        VStack {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                // Cardinal directions
                ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                    CompassDirectionText(direction: direction)
                }
                
                // Inner circle
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 70, height: 70)
                
                // Compass needle
                CompassNeedle()
                    .fill(Color.red)
                    .frame(width: 5, height: 60)
                    .offset(y: -15)
                    .rotationEffect(Angle(degrees: -compassService.heading))
                
                // Center circle
                Circle()
                    .fill(Color.blue)
                    .frame(width: 15, height: 15)
                
                if compassService.isCalibrating {
                    Text("Calibrating...")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .offset(y: 50)
                }
            }
            
            Text("\(Int(compassService.heading))°")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}

struct CompassDirectionText: View {
    let direction: String
    
    var body: some View {
        let angle = directionToAngle(direction)
        return Text(direction)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .offset(y: -45)
            .rotationEffect(Angle(degrees: -angle))
            .rotationEffect(Angle(degrees: angle))
    }
    
    private func directionToAngle(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

struct CompassNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create arrow shape
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width, y: height / 4))
        path.addLine(to: CGPoint(x: width / 2, y: height))
        path.addLine(to: CGPoint(x: 0, y: height / 4))
        path.closeSubpath()
        
        return path
    }
}