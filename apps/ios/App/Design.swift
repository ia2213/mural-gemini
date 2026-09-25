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
        GeometryReader { geo in
            let isPad = min(geo.size.width, geo.size.height) > 500
            let cornerRadius: CGFloat = isPad ? 32 : 55
            
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let speed: Double = listening ? 55 : 35
                let rotation = Angle.degrees((t * speed).truncatingRemainder(dividingBy: 360))
                let pulse = sin(t * 3.0) * 0.08
                
                // Vibrant Apple Intelligence / Siri Glowing Color Palette
                let siriColors: [Color] = [
                    Color(red: 0.05, green: 0.55, blue: 1.00), // Vibrant Electric Blue
                    Color(red: 0.00, green: 0.95, blue: 1.00), // Siri Neon Cyan
                    Color(red: 0.70, green: 0.15, blue: 1.00), // Deep Neon Violet
                    Color(red: 1.00, green: 0.20, blue: 0.65), // Hot Apple Pink / Magenta
                    Color(red: 1.00, green: 0.55, blue: 0.10), // Radiant Amber / Coral
                    Color(red: 0.00, green: 0.95, blue: 1.00), // Neon Cyan accent
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
                    // 1. Broad Atmospheric Bloom (Soft & Deep Glow)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: listening ? 32 : 20)
                        .blur(radius: listening ? 32 : 20)
                        .opacity(listening ? 0.95 : 0.75 + pulse)
                        .blendMode(.plusLighter)
                    
                    // 2. Mid Luminous Core
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(reverseGradient, lineWidth: listening ? 14 : 9)
                        .blur(radius: listening ? 12 : 8)
                        .opacity(listening ? 1.0 : 0.85)
                    
                    // 3. Sharp Vibrant Light Beam (Glued right along physical bezel)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: listening ? 5.5 : 3.5)
                        .blur(radius: 2.5)
                        .opacity(1.0)
                    
                    // 4. Ultra-Crisp Highlight Rim
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(listening ? 0.65 : 0.40),
                            lineWidth: listening ? 1.5 : 1.0
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
