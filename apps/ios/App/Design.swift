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
            // Exact continuous squircle radius matching iPhone 12/13/14/15/16 OLED glass (48-55pt) & iPad (28pt)
            let cornerRadius: CGFloat = isPad ? 28 : (geo.safeAreaInsets.top > 50 ? 55 : (geo.safeAreaInsets.top > 20 ? 48 : 22))
            
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let clampedEnergy = reduceMotion ? 0.20 : min(1.0, max(0.0, energy))
                
                // Dynamic multi-color sweep speed
                let speed: Double = (listening ? 35 : 20) + clampedEnergy * 35
                let rotation = Angle.degrees((t * speed).truncatingRemainder(dividingBy: 360))
                let breathing = sin(t * 2.0) * 0.05
                
                // Authentic Apple Intelligence Siri & Gemini Live vibrant 8-Color Spectrum
                let siriColors: [Color] = [
                    Color(red: 0.05, green: 0.50, blue: 1.00), // Siri Electric Blue
                    Color(red: 0.00, green: 0.98, blue: 0.92), // Neon Cyan
                    Color(red: 0.10, green: 0.98, blue: 0.55), // Gemini Vivid Mint
                    Color(red: 1.00, green: 0.88, blue: 0.08), // Solar Gold
                    Color(red: 1.00, green: 0.40, blue: 0.10), // Radiant Coral
                    Color(red: 1.00, green: 0.10, blue: 0.65), // Hot Apple Pink / Magenta
                    Color(red: 0.68, green: 0.12, blue: 1.00), // Electric Purple / Violet
                    Color(red: 0.00, green: 0.98, blue: 0.92), // Neon Cyan
                    Color(red: 0.05, green: 0.50, blue: 1.00)  // Loop
                ]
                
                let gradientForward = AngularGradient(
                    gradient: Gradient(colors: siriColors),
                    center: .center,
                    angle: rotation
                )
                
                let gradientReverse = AngularGradient(
                    gradient: Gradient(colors: siriColors.reversed()),
                    center: .center,
                    angle: rotation + .degrees(140)
                )
                
                let gradientCross = AngularGradient(
                    gradient: Gradient(colors: siriColors),
                    center: .center,
                    angle: -rotation + .degrees(260)
                )
                
                let wideBloomWidth: CGFloat = (listening ? 38 : 26) + CGFloat(clampedEnergy * 20)
                let midGlowWidth: CGFloat = (listening ? 20 : 13) + CGFloat(clampedEnergy * 12)
                let coreBeamWidth: CGFloat = (listening ? 7.5 : 5.0) + CGFloat(clampedEnergy * 5.0)
                let rimWidth: CGFloat = 3.0 + CGFloat(clampedEnergy * 1.5)
                
                ZStack {
                    // 1. Broad Atmospheric Inward Neon Bleed (Thick Siri & Gemini glow flooding the perimeter)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientForward, lineWidth: wideBloomWidth)
                        .blur(radius: (listening ? 28 : 18) + CGFloat(clampedEnergy * 10))
                        .opacity(min(1.0, 0.75 + clampedEnergy * 0.25 + breathing))
                        .blendMode(.plusLighter)
                    
                    // 2. High-Intensity Mid Chromatic Ribbon
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientReverse, lineWidth: midGlowWidth)
                        .blur(radius: (listening ? 10 : 6) + CGFloat(clampedEnergy * 5))
                        .opacity(min(1.0, 0.85 + clampedEnergy * 0.15))
                        .blendMode(.plusLighter)
                    
                    // 3. Dynamic Multi-Hue Cross-Current Core
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientCross, lineWidth: coreBeamWidth)
                        .blur(radius: 3.0 + CGFloat(clampedEnergy * 2.0))
                        .opacity(min(1.0, 0.90 + clampedEnergy * 0.10))
                        .blendMode(.plusLighter)
                    
                    // 4. Sharp Crisp Edge Beam (Glued flush to physical bezel & screen corners)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientForward, lineWidth: rimWidth)
                        .blur(radius: 0.5)
                        .opacity(1.0)
                    
                    // 5. Apple Crystal Glass Specular Glint
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.40 + clampedEnergy * 0.40),
                            lineWidth: 1.2 + CGFloat(clampedEnergy * 0.8)
                        )
                        .blur(radius: 0.4)
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
