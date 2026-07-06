import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var settings: AppSettings?
    @State private var sendTime = Date.now
    @State private var showPaywall = false
    @State private var syncMessage: String?
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    messageSection(settings)
                    notificationSection(settings)
                }
                contactsSection
                proSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { loadSettings() }
            .onDisappear {
                try? context.save()
                Task { await Maintenance.run(context: context, isPro: store.isPro) }
            }
        }
    }

    private func loadSettings() {
        let s = AppSettings.fetchOrCreate(in: context)
        settings = s
        var comps = DateComponents()
        comps.hour = s.defaultSendHour
        comps.minute = s.defaultSendMinute
        sendTime = Calendar.current.date(from: comps) ?? .now
    }

    // MARK: - Sections

    private func messageSection(_ settings: AppSettings) -> some View {
        Section {
            TextField(
                MessageTemplate.defaultBirthday,
                text: Binding(
                    get: { settings.defaultMessageTemplate },
                    set: { settings.defaultMessageTemplate = $0 }
                ),
                axis: .vertical
            )
        } header: {
            Text("Default message")
        } footer: {
            Text("Use \(MessageTemplate.firstNameToken) to insert their name.")
        }
    }

    private func notificationSection(_ settings: AppSettings) -> some View {
        Section("Notifications") {
            DatePicker("Send time", selection: $sendTime, displayedComponents: .hourAndMinute)
                .onChange(of: sendTime) { _, newValue in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    settings.defaultSendHour = comps.hour ?? 9
                    settings.defaultSendMinute = comps.minute ?? 0
                }

            if store.isPro {
                Toggle("Belated Rescue", isOn: Binding(
                    get: { settings.belatedRescueEnabled },
                    set: { settings.belatedRescueEnabled = $0 }
                ))
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Text("Belated Rescue")
                            .foregroundStyle(.primary)
                        Spacer()
                        ProBadge()
                    }
                }
            }
        }
    }

    private var contactsSection: some View {
        Section {
            Button {
                Task { await resync() }
            } label: {
                HStack {
                    Text("Re-sync contacts")
                    Spacer()
                    if isSyncing {
                        ProgressView()
                    }
                }
            }
            .disabled(isSyncing)
        } header: {
            Text("Contacts")
        } footer: {
            if let syncMessage {
                Text(syncMessage)
            }
        }
    }

    private var proSection: some View {
        Section("Wisho PRO") {
            if store.isPro {
                Label("You're a PRO", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
                Link("Manage subscription", destination: WishoLinks.manageSubscriptions)
            } else {
                Button("Upgrade to PRO") { showPaywall = true }
            }
            Button("Restore purchases") {
                Task { await store.restore() }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link("Privacy policy", destination: WishoLinks.privacyPolicy)
            Link("Support", destination: WishoLinks.support)
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        }
    }

    // MARK: - Actions

    private func resync() async {
        guard ContactSyncService.authorizationStatus() == .authorized else {
            if await ContactSyncService.requestAccess() {
                await resync()
            } else {
                syncMessage = "Contacts access is off. Enable it in Settings to sync."
            }
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await ContactSyncService.sync(context: context, isPro: store.isPro)
            var parts: [String] = []
            if result.imported > 0 { parts.append("\(result.imported) added") }
            if result.updated > 0 { parts.append("\(result.updated) updated") }
            if result.skippedForLimit > 0 { parts.append("\(result.skippedForLimit) waiting for PRO") }
            syncMessage = parts.isEmpty ? "Everything is up to date." : parts.joined(separator: ", ") + "."
            await Maintenance.run(context: context, isPro: store.isPro)
        } catch {
            syncMessage = "Sync failed — try again."
        }
    }
}
