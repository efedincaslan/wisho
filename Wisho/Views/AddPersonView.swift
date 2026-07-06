import SwiftUI
import SwiftData

/// Minimal manual-add form — designed to take under 10 seconds.
struct AddPersonView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var month = Calendar.current.component(.month, from: .now)
    @State private var day = Calendar.current.component(.day, from: .now)
    @State private var includeYear = false
    @State private var year = 1990
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name (optional)", text: $lastName)
                        .textContentType(.familyName)
                }

                Section("Birthday") {
                    Picker("Month", selection: $month) {
                        ForEach(1...12, id: \.self) { m in
                            Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                        }
                    }
                    Picker("Day", selection: $day) {
                        ForEach(1...31, id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                    Toggle("Include year", isOn: $includeYear)
                    if includeYear {
                        Picker("Year", selection: $year) {
                            ForEach((1920...Calendar.current.component(.year, from: .now)).reversed(), id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                    }
                }

                Section("Phone (optional)") {
                    TextField("Phone number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
            }
            .navigationTitle("Add birthday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let person = Person(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: trimmedLast.isEmpty ? nil : trimmedLast,
            birthMonth: month,
            birthDay: day,
            birthYear: includeYear ? year : nil,
            phoneNumber: trimmedPhone.isEmpty ? nil : ContactSyncService.normalizePhone(trimmedPhone),
            source: .manual
        )
        context.insert(person)
        try? context.save()
        Haptics.tap()
        Task { await Maintenance.run(context: context, isPro: store.isPro) }
        dismiss()
    }
}
