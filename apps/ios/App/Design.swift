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
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !active || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let phase = t * 0.5
            let e = reduceMotion ? 0 : min(1, max(0, energy))
            
            ZStack {
                // Subtle edge glow on the screen perimeter
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.5 + e * 0.5),
                                Color(red: 0.85, green: 0.45, blue: 0.95).opacity(0.4 + e * 0.4),
                                Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.4 + e * 0.4),
                                Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.5 + e * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: listening ? 6 : 2
                    )
                    .blur(radius: listening ? 10 : 3)
                    .opacity(active ? 0.7 : 0.15)
                    .padding(2)
                
                // Very faint breathing radial gradient in background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.04 + e * 0.04),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .scaleEffect(1.0 + sin(phase) * 0.05)
            }
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
