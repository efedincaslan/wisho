import SwiftUI
import SwiftData

@main
struct WishoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = StoreManager()
    @State private var router = AppRouter.shared

    private let container: ModelContainer = {
        let schema = Schema([Person.self, WishEvent.self, AppSettings.self])
        // UI tests run against a fresh in-memory store.
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let testContainer = try? ModelContainer(
               for: schema,
               configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
           ) {
            return testContainer
        }
        // Only use the shared App Group store when the entitlement is actually
        // present — asking SwiftData for a group container without it can
        // crash at launch (e.g. free-signed sideloaded builds).
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil,
           let shared = try? ModelContainer(
               for: schema,
               configurations: [ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.identifier))]
           ) {
            return shared
        }
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .tint(.accentColor)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(AppRouter.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var people: [Person]

    var body: some View {
        @Bindable var router = router
        Group {
            if hasCompletedOnboarding {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .sheet(item: $router.pendingSend) { request in
            if let person = people.first(where: { $0.id == request.personId }) {
                SendSheetView(person: person, isBelated: request.isBelated)
            }
        }
        .sheet(isPresented: $router.showPostSendPaywall) {
            PaywallView(headline: "You just made someone's day. Never miss anyone — go PRO.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, hasCompletedOnboarding {
                Task { await Maintenance.run(context: context, isPro: store.isPro) }
            }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                UITestSeed.populateIfNeeded(context: context)
            }
        }
    }
}
