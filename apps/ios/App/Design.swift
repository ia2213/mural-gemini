import SwiftUI

enum FluenceColor {
    static let background = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1.0)
            : UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0)
    })
    static let surface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.12, blue: 0.17, alpha: 1.0)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })
    static let ink = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1.0)
            : UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0)
    })
    static let secondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1.0)
            : UIColor(red: 0.42, green: 0.48, blue: 0.56, alpha: 1.0)
    })
    static let accent = Color(red: 0.35, green: 0.45, blue: 0.95) // Soft Apple Indigo
    
    // Legacy mapping to avoid breaking other views immediately
    static let cream = surface
    static let orange = accent
    static let peach = Color(red: 0.85, green: 0.88, blue: 0.95)
    static let lilac = Color(red: 0.80, green: 0.82, blue: 0.95)
    static let sage = Color(red: 0.80, green: 0.90, blue: 0.90)
    static let butter = Color(red: 0.92, green: 0.90, blue: 0.80)
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
        if reduceTransparency { content.background(FluenceColor.surface, in: Capsule()) }
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
            let topInset = geo.safeAreaInsets.top
            // Precise physical device screen corner radius detection
            let cornerRadius: CGFloat = {
                if isPad { return 24 }
                if topInset > 50 { return 54 } // Dynamic Island models (iPhone 14/15/16 Pro)
                if topInset > 30 { return 47 } // Notch models (iPhone X/11/12/13/14)
                return 18 // Standard / SE
            }()
            
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let clampedEnergy = reduceMotion ? 0.2 : min(1.0, max(0.0, energy))
                let dynamicSpeed: Double = (listening ? 35 : 20) + clampedEnergy * 30
                let rotation = Angle.degrees((t * dynamicSpeed).truncatingRemainder(dividingBy: 360))
                
                // Gentle, elegant Apple Intelligence glow colors (softened, not aggressive)
                let siriColors: [Color] = [
                    Color(red: 0.20, green: 0.55, blue: 0.95), // Soft Electric Blue
                    Color(red: 0.10, green: 0.85, blue: 0.90), // Soft Siri Cyan
                    Color(red: 0.65, green: 0.30, blue: 0.95), // Soft Violet
                    Color(red: 0.95, green: 0.35, blue: 0.65), // Soft Apple Rose
                    Color(red: 0.95, green: 0.60, blue: 0.25), // Warm Amber
                    Color(red: 0.10, green: 0.85, blue: 0.90), // Soft Cyan
                    Color(red: 0.20, green: 0.55, blue: 0.95)  // Loop
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
                
                let bloomWidth: CGFloat = (listening ? 16 : 10) + CGFloat(clampedEnergy * 10)
                let coreWidth: CGFloat = (listening ? 6 : 4) + CGFloat(clampedEnergy * 4)
                let beamWidth: CGFloat = 2.5 + CGFloat(clampedEnergy * 1.5)
                
                ZStack {
                    // 1. Soft Atmospheric Bloom (Deep, gentle and diffuse)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: bloomWidth)
                        .blur(radius: (listening ? 18 : 10) + CGFloat(clampedEnergy * 8))
                        .opacity(min(0.65, 0.40 + clampedEnergy * 0.25))
                    
                    // 2. Mid Luminous Contour
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(reverseGradient, lineWidth: coreWidth)
                        .blur(radius: (listening ? 6 : 3) + CGFloat(clampedEnergy * 3))
                        .opacity(min(0.75, 0.50 + clampedEnergy * 0.25))
                    
                    // 3. Delicate Crisp Perimeter
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradient, lineWidth: beamWidth)
                        .blur(radius: 0.8)
                        .opacity(0.85)
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
