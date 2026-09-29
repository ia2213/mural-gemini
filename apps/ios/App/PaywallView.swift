import SwiftUI
import StoreKit

public struct PaywallView: View {
    @StateObject private var storeKit = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Background Theme matching Fluence's 3D wave aura
            LinearGradient(
                colors: [Color(hex: "#120B24"), Color(hex: "#1A0F3D"), Color(hex: "#241842")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header Brand Elements
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#9F7AEA"), Color(hex: "#63B3ED")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 84, height: 84)
                                .opacity(0.15)
                                .blur(radius: 8)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(colors: [.white, Color(hex: "#A3BFFA")], startPoint: .top, endPoint: .bottom)
                                )
                        }
                        .padding(.top, 24)
                        
                        Text("Fluence Premium")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Libérez votre plein potentiel linguistique")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Feature List Highlights
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "waveform.path", title: "Conversations Vocales Illimitées", subtitle: "Plus aucune limite de temps ou d'usage quotidien.")
                        FeatureRow(icon: "wand.and.stars", title: "Moteurs d'IA Avancés & HD", subtitle: "Accès prioritaire à Claude-3.5, GPT-4o et voix studio ultra-réalistes.")
                        FeatureRow(icon: "face.smiling", title: "Mode Enfant Premium", subtitle: "Suivi intelligent de la progression et histoires immersives pour vos enfants.")
                        FeatureRow(icon: "globe", title: "Plus de 25 Langues", subtitle: "Basculez librement d'une langue à l'autre instantanément.")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    )
                    .padding(.horizontal, 20)
                    
                    // Subscription Product Options
                    if storeKit.products.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(storeKit.products, id: \.id) { product in
                                ProductCard(product: product, isSelected: true) {
                                    Task {
                                        await purchaseProduct(product)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Restore Purchases and Legal Links
                    HStack(spacing: 24) {
                        Button("Restaurer les achats") {
                            Task {
                                await storeKit.restorePurchases()
                                if storeKit.isPremium {
                                    dismiss()
                                }
                            }
                        }
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Link("Conditions", destination: URL(string: "https://fluence-agent.nousresearch.com/terms")!)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Link("Confidentialité", destination: URL(string: "https://fluence-agent.nousresearch.com/privacy")!)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await storeKit.purchase(product)
            if storeKit.isPremium {
                dismiss()
            }
        } catch {
            errorMessage = "Échec du paiement. Veuillez réessayer."
        }
        isPurchasing = false
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "#9F7AEA"), Color(hex: "#63B3ED")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    var isYearly: Bool {
        product.id.contains("yearly")
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        if isYearly {
                            Text("ÉCONOMIE 50%")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#48BB78"))
                                .cornerRadius(4)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Text(isYearly ? "/ an" : "/ mois")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isYearly ? Color(hex: "#9F7AEA").opacity(0.12) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isYearly ? Color(hex: "#9F7AEA").opacity(0.6) : Color.white.opacity(0.15), lineWidth: isYearly ? 2 : 1)
                    )
            )
        }
    }
}
