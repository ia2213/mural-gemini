import SwiftUI

@main struct FluenceApp: App {
    @State private var store: LearningStore?
    @State private var startupError: String?
    init() {
        do { _store = State(initialValue: try LearningStore(inMemory: ProcessInfo.processInfo.arguments.contains("--preview") || AudioVerification.requested)) }
        catch { _startupError = State(initialValue: "Fluence couldn’t open its learning record. Your existing data has not been replaced.") }
    }
    
    private var colorScheme: ColorScheme? {
        guard let store else { return nil }
        switch store.preferences.appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil // System default
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if let store {
                RootView(store: store)
                    .preferredColorScheme(colorScheme)
                    .task {
                        _ = await NotificationManager.shared.requestAuthorization()
                    }
            }
            else {
                ContentUnavailableView("Let’s try again", systemImage: "externaldrive.badge.exclamationmark", description: Text(startupError ?? "The learning record is unavailable."))
                    .preferredColorScheme(colorScheme)
            }
        }
    }
}
