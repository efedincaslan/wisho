import SwiftUI
import SwiftData
import PhotosUI

struct PersonDetailView: View {
    @Bindable var person: Person

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @Query private var events: [WishEvent]

    @State private var includeYear: Bool
    @State private var selectedYear: Int
    @State private var photoItem: PhotosPickerItem?
    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false

    init(person: Person) {
        self.person = person
        let personId = person.id
        _events = Query(
            filter: #Predicate<WishEvent> { $0.personId == personId },
            sort: \WishEvent.date, order: .reverse
        )
        _includeYear = State(initialValue: person.birthYear != nil)
        _selectedYear = State(initialValue: person.birthYear ?? 1990)
    }

    var body: some View {
        Form {
            identitySection
            birthdaySection
            contactSection
            remindersSection
            if !events.isEmpty {
                historySection
            }
            deleteSection
        }
        .navigationTitle(person.firstName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onDisappear {
            try? context.save()
            Task { await Maintenance.run(context: context, isPro: store.isPro) }
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    AvatarView(person: person, size: 80)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor, Color(.systemBackground))
                        }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        person.photoData = data
                    }
                }
            }

            TextField("First name", text: $person.firstName)
            TextField("Last name", text: Binding(
                get: { person.lastName ?? "" },
                set: { person.lastName = $0.isEmpty ? nil : $0 }
            ))
        }
    }

    private var birthdaySection: some View {
        Section("Birthday") {
            Picker("Month", selection: $person.birthMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                }
            }
            Picker("Day", selection: $person.birthDay) {
                ForEach(1...31, id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            Toggle("Include year", isOn: $includeYear)
                .onChange(of: includeYear) { _, on in
                    person.birthYear = on ? selectedYear : nil
                }
            if includeYear {
                Picker("Year", selection: $selectedYear) {
                    ForEach((1920...Calendar.current.component(.year, from: .now)).reversed(), id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .onChange(of: selectedYear) { _, y in
                    person.birthYear = y
                }
            }
        }
    }

    private var contactSection: some View {
        Section("Phone") {
            TextField("Phone number", text: Binding(
                get: { person.phoneNumber ?? "" },
                set: { person.phoneNumber = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle("Remind me", isOn: $person.isEnabled)

            proRow(title: "Heads-up reminder") {
                Picker("Heads-up reminder", selection: $person.reminderLeadDays) {
                    Text("Day of only").tag(0)
                    Text("1 day before").tag(1)
                    Text("3 days before").tag(3)
                    Text("7 days before").tag(7)
                }
            }

            proRow(title: "Timezone") {
                NavigationLink {
                    TimeZonePickerView(selection: $person.timezoneIdentifier)
                } label: {
                    LabeledContent("Timezone", value: person.timezoneIdentifier ?? "My timezone")
                }
            }

            proRow(title: "Custom message") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom message")
                        .font(.subheadline)
                    TextField(
                        MessageTemplate.defaultBirthday,
                        text: Binding(
                            get: { person.customMessage ?? "" },
                            set: { person.customMessage = $0.isEmpty ? nil : $0 }
                        ),
                        axis: .vertical
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// PRO features render normally for subscribers; locked row otherwise.
    @ViewBuilder
    private func proRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        if store.isPro {
            content()
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    ProBadge()
                }
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            ForEach(events) { event in
                HStack(spacing: 10) {
                    Image(systemName: event.type.symbolName)
                        .foregroundStyle(event.type == .missed ? .orange : Color.accentColor)
                    Text(event.type.label)
                    Spacer()
                    Text(event.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete \(person.firstName)", role: .destructive) {
                showDeleteConfirmation = true
            }
            .frame(maxWidth: .infinity)
            .confirmationDialog(
                "Delete \(person.fullName)? Their wish history goes too.",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    for event in events {
                        context.delete(event)
                    }
                    context.delete(person)
                    try? context.save()
                    dismiss()
                }
            }
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
    }
}
