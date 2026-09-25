import SwiftUI

enum FluenceColor {
    static let background = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ? UIColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1.0) : UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
    })
    static let ink = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ? UIColor(white: 0.96, alpha: 1.0) : UIColor(red: 0.11, green: 0.13, blue: 0.16, alpha: 1.0)
    })
    static let secondary = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ? UIColor(white: 0.65, alpha: 1.0) : UIColor(white: 0.45, alpha: 1.0)
    })
    static let accent = Color(red: 0.35, green: 0.45, blue: 0.95)
    
    // Legacy mapping to avoid breaking other views immediately
    static let cream = background
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
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let rotation = Angle.degrees((t * 35).truncatingRemainder(dividingBy: 360))
            
            let auraColors: [Color] = [
                Color(red: 0.15, green: 0.45, blue: 0.98), // Electric Royal Blue
                Color(red: 0.02, green: 0.75, blue: 0.95), // Siri Cyan
                Color(red: 0.65, green: 0.25, blue: 0.95), // Gemini Neon Purple
                Color(red: 0.98, green: 0.35, blue: 0.65), // Rose Magenta
                Color(red: 0.98, green: 0.55, blue: 0.20), // Sunset Amber
                Color(red: 0.15, green: 0.45, blue: 0.98)  // Loop back
            ]
            
            ZStack {
                // Layer 1: Wide Diffuse Atmospheric Edge Glow (Siri / Gemini Style)
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: auraColors),
                            center: .center,
                            angle: rotation
                        ),
                        lineWidth: listening ? 14 : 7
                    )
                    .blur(radius: listening ? 18 : 10)
                    .opacity(listening ? 0.90 : 0.60)
                
                // Layer 2: Crisp Vibrant Border
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: auraColors),
                            center: .center,
                            angle: rotation + .degrees(180)
                        ),
                        lineWidth: listening ? 3.5 : 2.0
                    )
                    .blur(radius: listening ? 2 : 1)
                    .opacity(listening ? 1.0 : 0.85)
            }
            .padding(4)
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
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
