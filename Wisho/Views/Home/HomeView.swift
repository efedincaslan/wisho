import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(sort: \Person.firstName) private var people: [Person]

    @State private var showSettings = false
    @State private var showAddPerson = false
    @State private var showPaywall = false
    @State private var notificationsDenied = false
    @State private var contactsDenied = false

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    emptyState
                } else {
                    birthdayList
                }
            }
            .navigationTitle("Wisho")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if store.canAddPerson(currentCount: people.count) {
                            showAddPerson = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addPersonButton")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAddPerson) { AddPersonView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .task { await refreshPermissionBanners() }
            .refreshable { await resyncContacts() }
        }
    }

    // MARK: - Buckets

    private struct PersonOccurrence: Identifiable {
        let person: Person
        let occurrence: BirthdayOccurrence
        var id: UUID { person.id }
    }

    private struct MonthGroup: Identifiable {
        let label: String
        let items: [PersonOccurrence]
        var id: String { label }
    }

    private var enabledPeople: [Person] { people.filter(\.isEnabled) }

    private var todayPeople: [Person] {
        enabledPeople.filter(\.isBirthdayToday)
    }

    private var missedPeople: [PersonOccurrence] {
        enabledPeople
            .filter { !$0.isBirthdayToday }
            .compactMap { p in p.missedOccurrence().map { PersonOccurrence(person: p, occurrence: $0) } }
            .sorted { $0.occurrence.date > $1.occurrence.date }
    }

    private var upcoming: [PersonOccurrence] {
        enabledPeople
            .filter { !$0.isBirthdayToday }
            .compactMap { p in p.nextOccurrence().map { PersonOccurrence(person: p, occurrence: $0) } }
            .sorted { $0.occurrence.date < $1.occurrence.date }
    }

    private var comingUp: [PersonOccurrence] {
        upcoming.filter { daysAway($0.occurrence) <= 30 }
    }

    private var later: [MonthGroup] {
        let items = upcoming.filter { daysAway($0.occurrence) > 30 }
        let grouped = Dictionary(grouping: items) { item in
            item.occurrence.date.formatted(.dateTime.month(.wide).year())
        }
        return grouped
            .map { MonthGroup(label: $0.key, items: $0.value.sorted { $0.occurrence.date < $1.occurrence.date }) }
            .sorted { $0.items[0].occurrence.date < $1.items[0].occurrence.date }
    }

    private func daysAway(_ occurrence: BirthdayOccurrence) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: occurrence.date).day ?? 0
    }

    // MARK: - List

    private var birthdayList: some View {
        List {
            if notificationsDenied {
                Section { notificationsBanner }
            }
            if contactsDenied {
                Section { contactsBanner }
            }
            if !store.isPro && people.count >= StoreManager.freePersonLimit {
                Section { upsellBanner }
            }

            if !todayPeople.isEmpty {
                Section("Today") {
                    ForEach(todayPeople) { person in
                        TodayCard(person: person) {
                            router.openSendSheet(personId: person.id, isBelated: false)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !missedPeople.isEmpty {
                Section("Missed") {
                    ForEach(missedPeople) { item in
                        MissedCard(person: item.person, occurrence: item.occurrence) {
                            router.openSendSheet(personId: item.person.id, isBelated: true)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !comingUp.isEmpty {
                Section("Coming up") {
                    ForEach(comingUp) { item in
                        NavigationLink {
                            PersonDetailView(person: item.person)
                        } label: {
                            PersonRow(person: item.person, occurrence: item.occurrence)
                        }
                    }
                }
            }

            if !later.isEmpty {
                Section("Later") {
                    ForEach(later) { group in
                        DisclosureGroup(group.label) {
                            ForEach(group.items) { item in
                                NavigationLink {
                                    PersonDetailView(person: item.person)
                                } label: {
                                    PersonRow(person: item.person, occurrence: item.occurrence)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Banners & empty state

    private var notificationsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off")
                    .font(.subheadline.weight(.semibold))
                Text("Wisho can't remind you without them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private var contactsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Contacts access is off")
                    .font(.subheadline.weight(.semibold))
                Text("Your birthdays are safe — re-enable to sync new ones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private var upsellBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free plan tracks \(StoreManager.freePersonLimit) people")
                        .font(.subheadline.weight(.semibold))
                    Text("Unlock everyone with Wisho PRO.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No birthdays yet", systemImage: "gift")
        } description: {
            Text("Add someone manually, or let Wisho import birthdays from your contacts.")
        } actions: {
            Button("Add a birthday") { showAddPerson = true }
                .buttonStyle(.borderedProminent)
            Button("Import from contacts") {
                Task {
                    if await ContactSyncService.requestAccess() {
                        await resyncContacts()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func refreshPermissionBanners() async {
        notificationsDenied = await NotificationEngine.shared.authorizationStatus() == .denied
        contactsDenied = ContactSyncService.authorizationStatus() == .denied && people.contains { $0.source == .contacts }
    }

    private func resyncContacts() async {
        guard ContactSyncService.authorizationStatus() == .authorized else {
            await refreshPermissionBanners()
            return
        }
        _ = try? await ContactSyncService.sync(context: context, isPro: store.isPro)
        await Maintenance.run(context: context, isPro: store.isPro)
    }
}
