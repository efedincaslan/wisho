import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store

    @State private var page = 0
    @State private var isFinishing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            TabView(selection: $page) {
                hookPage.tag(0)
                contactsPage.tag(1)
                notificationsPage.tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    // MARK: - Page 1: hook

    private var hookPage: some View {
        OnboardingPage(
            symbol: "gift.fill",
            title: "Never miss a birthday again.",
            subtitle: "Wisho watches the calendar so you don't have to — and makes sending the wish one tap."
        ) {
            Button("Get started") {
                withAnimation { page = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Page 2: contacts

    private var contactsPage: some View {
        OnboardingPage(
            symbol: "person.crop.circle.badge.checkmark",
            title: "Bring in your people",
            subtitle: "Wisho reads birthdays from your contacts. Nothing ever leaves your phone."
        ) {
            VStack(spacing: 12) {
                Button("Allow contacts access") {
                    Task {
                        _ = await ContactSyncService.requestAccess()
                        withAnimation { page = 2 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Add birthdays manually instead") {
                    withAnimation { page = 2 }
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Page 3: notifications

    private var notificationsPage: some View {
        OnboardingPage(
            symbol: "bell.badge.fill",
            title: "One tap and it's sent",
            subtitle: "This is how Wisho works — one tap on the notification and your wish is sent."
        ) {
            VStack(spacing: 12) {
                Button {
                    finish(requestNotifications: true)
                } label: {
                    if isFinishing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Enable notifications")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isFinishing)

                Button("Not now") {
                    finish(requestNotifications: false)
                }
                .font(.subheadline)
                .disabled(isFinishing)
            }
        }
    }

    private func finish(requestNotifications: Bool) {
        isFinishing = true
        Task {
            if requestNotifications {
                _ = await NotificationEngine.shared.requestAuthorization()
            }
            if ContactSyncService.authorizationStatus() == .authorized {
                _ = try? await ContactSyncService.sync(context: context, isPro: store.isPro)
            }
            await Maintenance.run(context: context, isPro: store.isPro)
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingPage<Actions: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
                .padding(32)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer()
            actions
            Spacer().frame(height: 48)
        }
        .padding(.horizontal, 32)
    }
}
