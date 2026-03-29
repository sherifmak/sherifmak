import SwiftUI

// MARK: - Tamagotchi Character View
// Used by both the main app and the widget.
// Widget-safe: no animations, no .onAppear, no @State.
// The app wraps this in TamagotchiAnimatedCharacter for bounce effects.

struct TamagotchiCharacter: View {
    let strainLevel: StrainLevel
    let strain: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Body
                Ellipse()
                    .fill(bodyColor)
                    .frame(width: 80, height: 70)
                    .shadow(color: bodyColor.opacity(0.4), radius: 8, y: 4)

                // Face
                VStack(spacing: 2) {
                    eyesView
                    mouthView
                }
                .offset(y: -2)

                // Sweat drops for high strain
                if strainLevel == .high || strainLevel == .overreach {
                    sweatDrops
                }

                // Zzz for resting
                if strainLevel == .resting {
                    sleepIndicator
                }

                // Sparkles for light activity
                if strainLevel == .light {
                    sparkles
                }
            }

            // Strain bar
            strainBar

            // Label
            Text(strainLevel.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Eyes

    @ViewBuilder
    private var eyesView: some View {
        HStack(spacing: 16) {
            switch strainLevel {
            case .resting:
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 12, height: 3)
                    .foregroundColor(.black)
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 12, height: 3)
                    .foregroundColor(.black)

            case .light:
                Circle()
                    .fill(Color.black)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.black)
                    .frame(width: 8, height: 8)

            case .moderate:
                VStack(spacing: 1) {
                    Rectangle()
                        .frame(width: 12, height: 2)
                        .foregroundColor(.black)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                }
                VStack(spacing: 1) {
                    Rectangle()
                        .frame(width: 12, height: 2)
                        .foregroundColor(.black)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                }

            case .high:
                Ellipse()
                    .fill(Color.black)
                    .frame(width: 10, height: 6)
                Ellipse()
                    .fill(Color.black)
                    .frame(width: 10, height: 6)

            case .overreach:
                Text("X")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.black)
                Text("X")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.black)
            }
        }
    }

    // MARK: - Mouth

    @ViewBuilder
    private var mouthView: some View {
        switch strainLevel {
        case .resting:
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 14, height: 3)
                .foregroundColor(.black.opacity(0.6))

        case .light:
            HalfCircle()
                .fill(Color.black)
                .frame(width: 18, height: 9)

        case .moderate:
            HalfCircle()
                .fill(Color.black)
                .frame(width: 14, height: 6)

        case .high:
            Ellipse()
                .fill(Color.black)
                .frame(width: 12, height: 10)
                .overlay(
                    Ellipse()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 8, height: 5)
                        .offset(y: 1)
                )

        case .overreach:
            WavyMouth()
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 18, height: 8)
        }
    }

    // MARK: - Accessories

    private var sweatDrops: some View {
        Group {
            Circle()
                .fill(Color.blue.opacity(0.6))
                .frame(width: 5, height: 5)
                .offset(x: 35, y: -20)
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 4, height: 4)
                .offset(x: 38, y: -10)
        }
    }

    private var sleepIndicator: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("z")
                .font(.system(size: 8, weight: .bold, design: .rounded))
            Text("z")
                .font(.system(size: 10, weight: .bold, design: .rounded))
            Text("Z")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(.blue.opacity(0.5))
        .offset(x: 35, y: -25)
    }

    private var sparkles: some View {
        Group {
            Image(systemName: "sparkle")
                .font(.system(size: 8))
                .foregroundColor(.yellow)
                .offset(x: -35, y: -25)
            Image(systemName: "sparkle")
                .font(.system(size: 6))
                .foregroundColor(.yellow)
                .offset(x: 38, y: -15)
        }
    }

    // MARK: - Strain Bar

    private var strainBar: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(bodyColor)
                        .frame(width: geo.size.width * CGFloat(min(strain / 21.0, 1.0)), height: 6)
                }
            }
            .frame(height: 6)

            Text(String(format: "%.1f / 21", strain))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(width: 80)
    }

    // MARK: - Helpers

    var bodyColor: Color {
        switch strainLevel {
        case .resting:   return Color(red: 0.55, green: 0.75, blue: 0.95)
        case .light:     return Color(red: 0.55, green: 0.90, blue: 0.60)
        case .moderate:  return Color(red: 0.95, green: 0.85, blue: 0.35)
        case .high:      return Color(red: 0.95, green: 0.60, blue: 0.30)
        case .overreach: return Color(red: 0.95, green: 0.35, blue: 0.35)
        }
    }
}

// MARK: - Animated Wrapper (App Only — NOT for WidgetKit)

struct TamagotchiAnimatedCharacter: View {
    let strainLevel: StrainLevel
    let strain: Double
    @State private var bounceOffset: CGFloat = 0

    var body: some View {
        TamagotchiCharacter(strainLevel: strainLevel, strain: strain)
            .offset(y: bounceOffset)
            .onAppear {
                withAnimation(bounceAnimation) {
                    bounceOffset = -4
                }
            }
    }

    private var bounceAnimation: Animation {
        switch strainLevel {
        case .resting:   return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case .light:     return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        case .moderate:  return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case .high:      return .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        case .overreach: return .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
        }
    }
}

// MARK: - Custom Shapes

struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct WavyMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.3, y: 0),
            control2: CGPoint(x: rect.width * 0.7, y: rect.height)
        )
        return path
    }
}

// MARK: - Preview

#Preview("All Strain Levels") {
    HStack(spacing: 20) {
        TamagotchiAnimatedCharacter(strainLevel: .resting, strain: 2.0)
        TamagotchiAnimatedCharacter(strainLevel: .light, strain: 6.0)
        TamagotchiAnimatedCharacter(strainLevel: .moderate, strain: 10.5)
        TamagotchiAnimatedCharacter(strainLevel: .high, strain: 15.0)
        TamagotchiAnimatedCharacter(strainLevel: .overreach, strain: 19.5)
    }
    .padding()
}
