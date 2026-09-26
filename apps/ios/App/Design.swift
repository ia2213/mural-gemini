import SwiftUI

import SwiftUI

enum FluenceColor {
    static let background = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1.0)
            : UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
    })
    static let surface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.85)
            : UIColor(white: 1.0, alpha: 0.90)
    })
    static let surfaceSecondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 0.70)
            : UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 0.80)
    })
    static let ink = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.98, blue: 1.00, alpha: 1.0)
            : UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1.0)
    })
    static let secondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.66, blue: 0.76, alpha: 1.0)
            : UIColor(red: 0.40, green: 0.46, blue: 0.54, alpha: 1.0)
    })
    static let accent = Color(red: 0.38, green: 0.48, blue: 0.98) // Luminous Royal Indigo
    static let emerald = Color(red: 0.15, green: 0.85, blue: 0.55) // Symbiote Active Mint
    static let amber = Color(red: 1.00, green: 0.65, blue: 0.20) // Symbiote Solar Amber
    static let rose = Color(red: 0.98, green: 0.30, blue: 0.60) // Symbiote Hot Rose
    
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

// MARK: - Organic Glass Container Modifier
struct OrganicGlass: ViewModifier {
    var cornerRadius: CGFloat = 24
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(FluenceColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.12)
                                    : Color.black.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, x: 0, y: 6)
            }
    }
}

extension View {
    func organicGlass(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(OrganicGlass(cornerRadius: cornerRadius))
    }
}

// MARK: - LIVING SYMBIOTE CORE (L'Organisme Vivant & Tactile)
struct SymbioteCoreView: View {
    var energy: Double = 0
    var isListening: Bool = false
    var isSpeaking: Bool = false
    var isThinking: Bool = false
    var onTap: (() -> Void)? = nil
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let rawE = min(1.0, max(0.0, energy))
            let dynamicE = reduceMotion ? 0.2 : rawE
            
            // Living rhythmic pulses
            let breath = sin(t * 1.8) * 0.08
            let wave1 = sin(t * 2.4) * 0.12
            let wave2 = cos(t * 3.1) * 0.10
            
            // Base scale modulated by voice energy
            let baseScale: CGFloat = 1.0 + (isListening ? 0.15 : (isSpeaking ? 0.18 : 0.0)) + CGFloat(dynamicE * 0.28) + CGFloat(breath)
            
            // Symbiote Color Spectrum
            let colors1: [Color] = isListening ? [
                Color(red: 0.00, green: 0.95, blue: 0.85), // Neon Cyan
                Color(red: 0.15, green: 0.88, blue: 0.55), // Emerald
                Color(red: 0.20, green: 0.60, blue: 1.00), // Siri Blue
                Color(red: 0.00, green: 0.95, blue: 0.85)
            ] : isSpeaking ? [
                Color(red: 1.00, green: 0.20, blue: 0.65), // Hot Magenta
                Color(red: 1.00, green: 0.60, blue: 0.20), // Solar Coral
                Color(red: 0.65, green: 0.25, blue: 1.00), // Electric Violet
                Color(red: 0.10, green: 0.55, blue: 1.00), // Blue
                Color(red: 1.00, green: 0.20, blue: 0.65)
            ] : [
                Color(red: 0.25, green: 0.45, blue: 1.00), // Deep Indigo
                Color(red: 0.60, green: 0.25, blue: 0.95), // Violet
                Color(red: 0.10, green: 0.85, blue: 0.90), // Soft Cyan
                Color(red: 0.25, green: 0.45, blue: 1.00)
            ]
            
            let rot1 = Angle.degrees((t * (isListening ? 45 : (isSpeaking ? 55 : 22))).truncatingRemainder(dividingBy: 360))
            let rot2 = Angle.degrees((-t * (isListening ? 35 : (isSpeaking ? 40 : 18))).truncatingRemainder(dividingBy: 360))
            
            Button {
                let haptic = UIImpactFeedbackGenerator(style: .medium)
                haptic.impactOccurred()
                onTap?()
            } label: {
                ZStack {
                    // 1. Outermost Bioluminescent Atmospheric Aura
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    colors1[0].opacity(0.35 + dynamicE * 0.30),
                                    colors1[1].opacity(0.18 + dynamicE * 0.18),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 130
                            )
                        )
                        .scaleEffect(baseScale * 1.45)
                        .blur(radius: 24)
                        .blendMode(.plusLighter)
                    
                    // 2. Symbiote Outer Liquid Membrane (Morphing Organism)
                    Circle()
                        .fill(
                            AngularGradient(gradient: Gradient(colors: colors1), center: .center, angle: rot1)
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(x: baseScale * (1.0 + CGFloat(wave1)), y: baseScale * (1.0 - CGFloat(wave2)))
                        .rotationEffect(rot1)
                        .blur(radius: 14)
                        .opacity(0.78 + dynamicE * 0.22)
                        .blendMode(.plusLighter)
                    
                    // 3. Counter-Fluid Inner Cytoplasmic Ring
                    Circle()
                        .fill(
                            AngularGradient(gradient: Gradient(colors: colors1.reversed()), center: .center, angle: rot2)
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(x: baseScale * (1.0 - CGFloat(wave2)), y: baseScale * (1.0 + CGFloat(wave1)))
                        .rotationEffect(rot2)
                        .blur(radius: 6)
                        .opacity(0.85 + dynamicE * 0.15)
                    
                    // 4. Luminous Symbiotic Nucleus (Intelligent Core)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    colors1[0].opacity(0.80),
                                    colors1[1].opacity(0.50),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 45
                            )
                        )
                        .frame(width: 70, height: 70)
                        .scaleEffect(1.0 + CGFloat(dynamicE * 0.35))
                        .blur(radius: 2.0)
                    
                    // 5. Central Living Waveform Icon Indicator
                    Image(systemName: isListening ? "waveform" : isSpeaking ? "sparkles" : "waveform.circle.fill")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color.black.opacity(0.4), radius: 4)
                }
                .frame(width: 220, height: 220)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isListening ? "Le symbiote vous écoute" : isSpeaking ? "Le symbiote vous répond" : "Touchez pour parler au symbiote")
        }
    }
}

// MARK: - AMBIENT PERIPHERAL SCREEN GLOW
struct FluenceAura: View {
    var energy: Double = 0
    var listening = false
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let isPad = min(geo.size.width, geo.size.height) > 500
            let cornerRadius: CGFloat = isPad ? 28 : (geo.safeAreaInsets.top > 50 ? 55 : (geo.safeAreaInsets.top > 20 ? 48 : 22))
            
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let clampedEnergy = reduceMotion ? 0.20 : min(1.0, max(0.0, energy))
                
                let speed: Double = (listening ? 35 : 20) + clampedEnergy * 35
                let rotation = Angle.degrees((t * speed).truncatingRemainder(dividingBy: 360))
                let breathing = sin(t * 2.0) * 0.05
                
                let siriColors: [Color] = [
                    Color(red: 0.05, green: 0.50, blue: 1.00),
                    Color(red: 0.00, green: 0.98, blue: 0.92),
                    Color(red: 0.10, green: 0.98, blue: 0.55),
                    Color(red: 1.00, green: 0.88, blue: 0.08),
                    Color(red: 1.00, green: 0.40, blue: 0.10),
                    Color(red: 1.00, green: 0.10, blue: 0.65),
                    Color(red: 0.68, green: 0.12, blue: 1.00),
                    Color(red: 0.00, green: 0.98, blue: 0.92),
                    Color(red: 0.05, green: 0.50, blue: 1.00)
                ]
                
                let gradientForward = AngularGradient(gradient: Gradient(colors: siriColors), center: .center, angle: rotation)
                let gradientReverse = AngularGradient(gradient: Gradient(colors: siriColors.reversed()), center: .center, angle: rotation + .degrees(140))
                let gradientCross = AngularGradient(gradient: Gradient(colors: siriColors), center: .center, angle: -rotation + .degrees(260))
                
                let wideBloomWidth: CGFloat = (listening ? 48 : 34) + CGFloat(clampedEnergy * 24)
                let midGlowWidth: CGFloat = (listening ? 26 : 18) + CGFloat(clampedEnergy * 14)
                let coreBeamWidth: CGFloat = (listening ? 12 : 8.0) + CGFloat(clampedEnergy * 6.0)
                
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientForward, lineWidth: wideBloomWidth)
                        .blur(radius: (listening ? 32 : 22) + CGFloat(clampedEnergy * 12))
                        .opacity(min(1.0, 0.80 + clampedEnergy * 0.20 + breathing))
                        .blendMode(.plusLighter)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientReverse, lineWidth: midGlowWidth)
                        .blur(radius: (listening ? 14 : 9) + CGFloat(clampedEnergy * 6))
                        .opacity(min(1.0, 0.88 + clampedEnergy * 0.12))
                        .blendMode(.plusLighter)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(gradientCross, lineWidth: coreBeamWidth)
                        .blur(radius: 6.0 + CGFloat(clampedEnergy * 3.0))
                        .opacity(min(1.0, 0.92 + clampedEnergy * 0.08))
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
