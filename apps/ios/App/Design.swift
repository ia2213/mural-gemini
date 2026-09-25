import SwiftUI

enum FluenceColor {
    static let background = Color.black
    static let surface = Color(red: 0.08, green: 0.11, blue: 0.16)
    static let ink = Color(white: 0.96)
    static let secondary = Color(white: 0.65)
    static let accent = Color(red: 0.35, green: 0.45, blue: 0.95)
    
    // Legacy mapping to avoid breaking other views immediately
    static let cream = surface
    static let orange = accent
    static let peach = Color(red: 0.9, green: 0.7, blue: 0.9)
    static let lilac = Color(red: 0.6, green: 0.5, blue: 0.9)
    static let sage = Color(red: 0.4, green: 0.8, blue: 0.8)
    static let butter = Color(red: 0.9, green: 0.9, blue: 0.5)
    static let panels = [peach, lilac, sage, butter]
}

struct Brand: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("fluence").font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-1.2)
        }.foregroundStyle(FluenceColor.ink).accessibilityLabel("Fluence")
    }
}

struct SoftGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var tint: Color = .white.opacity(0.45)
    func body(content: Content) -> some View {
        if reduceTransparency { content.background(.white, in: Capsule()) }
        else { content.background(.ultraThinMaterial, in: Capsule()) }
    }
}



struct FluenceAura: View {
    var energy: Double = 0
    var listening = false
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let isPad = min(geo.size.width, geo.size.height) > 500
            let cornerRadius: CGFloat = isPad ? 28 : 54
            
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let clampedEnergy = reduceMotion ? 0.3 : min(1.0, max(0.0, energy))
                let dynamicSpeed: Double = (listening ? 50 : 30) + clampedEnergy * 60
                let rotation = Angle.degrees((t * dynamicSpeed).truncatingRemainder(dividingBy: 360))
                
                // Voice Reactive Pulse Modulation
                let voicePulse = sin(t * 4.0) * (0.05 + clampedEnergy * 0.15)
                let bloomWidth: CGFloat = (listening ? 24 : 14) + CGFloat(clampedEnergy * 20)
                let coreWidth: CGFloat = (listening ? 10 : 6) + CGFloat(clampedEnergy * 8)
                let beamWidth: CGFloat = 3.5 + CGFloat(clampedEnergy * 4)
                
                // Intense Apple Intelligence Glowing Colors
                let siriColors: [Color] = [
                    Color(red: 0.05, green: 0.55, blue: 1.00), // Electric Siri Blue
                    Color(red: 0.00, green: 0.98, blue: 0.95), // Ultra Neon Cyan
                    Color(red: 0.68, green: 0.15, blue: 1.00), // Hot Violet
                    Color(red: 1.00, green: 0.18, blue: 0.65), // Vivid Apple Pink / Magenta
                    Color(red: 1.00, green: 0.55, blue: 0.05), // Radiant Amber
                    Color(red: 0.00, green: 0.98, blue: 0.95), // Ultra Neon Cyan
                    Color(red: 0.05, green: 0.55, blue: 1.00)  // Seamless loop
                ]
                
                let gradient = AngularGradient(
                    gradient: Gradient(colors: siriColors),
                    center: .center,
                    angle: rotation
                )
                
                let reverseGradient = AngularGradient(
                    gradient: Gradient(colors: siriColors.reversed()),
                    center: .center,
                    angle: rotation + .degrees(180)
                )
                
                ZStack {
                    // 1. Voice Reactive Atmospheric Bloom (Massive neon emission)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: bloomWidth)
                        .blur(radius: (listening ? 24 : 14) + CGFloat(clampedEnergy * 18))
                        .opacity(min(1.0, 0.75 + clampedEnergy * 0.25 + voicePulse))
                        .blendMode(.plusLighter)
                    
                    // 2. Mid Intense Radiance
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(reverseGradient, lineWidth: coreWidth)
                        .blur(radius: (listening ? 10 : 6) + CGFloat(clampedEnergy * 6))
                        .opacity(min(1.0, 0.85 + clampedEnergy * 0.15))
                        .blendMode(.plusLighter)
                    
                    // 3. Crisp Vibrant Edge Beam (Tight flush fit to screen bezel)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: beamWidth)
                        .blur(radius: 1.5)
                        .opacity(1.0)
                    
                    // 4. Ultra-Bright Glass Highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.40 + clampedEnergy * 0.50),
                            lineWidth: 1.2 + CGFloat(clampedEnergy * 1.5)
                        )
                        .blur(radius: 0.5)
                        .blendMode(.plusLighter)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct WhisperText: View {
    var text: AttributedString
    var isLarge: Bool = false
    
    var body: some View {
        Text(text)
            .font(.system(size: isLarge ? 32 : 18, weight: isLarge ? .bold : .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(isLarge ? FluenceColor.ink : FluenceColor.secondary)
            .animation(.easeInOut(duration: 0.3), value: String(text.characters))
    }
}

struct RecallBars: View {
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in Capsule().fill(index < count ? FluenceColor.orange : FluenceColor.peach).frame(width: 18, height: 6) }
        }.accessibilityLabel("\(count) of 3 recall bars")
    }
}

struct PageHeading: View {
    var eyebrow: String
    var title: String
    var subtitle: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased()).font(.system(.caption, design: .rounded, weight: .medium)).tracking(1.5).foregroundStyle(FluenceColor.secondary)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .semibold)).tracking(-1).foregroundStyle(FluenceColor.ink)
            if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(FluenceColor.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
