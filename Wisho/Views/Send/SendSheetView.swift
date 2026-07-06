import SwiftUI
import SwiftData
import MessageUI

/// The core interaction: pre-filled wish, one big send button.
struct SendSheetView: View {
    let person: Person
    let isBelated: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var message = ""
    @State private var showMessageCompose = false
    @State private var showConfetti = false
    @State private var copiedToClipboard = false
    @State private var isClosing = false

    private var canText: Bool {
        MessageComposeView.canSendText && person.phoneNumber?.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AvatarView(person: person, size: 88)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(person.fullName)
                        .font(.title2.bold())
                    Text(contextLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $message)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 110, maxHeight: 160)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                primaryButton

                secondaryOptions

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isClosing)
        .overlay {
            if showConfetti {
                ConfettiView()
            }
        }
        .sheet(isPresented: $showMessageCompose) {
            MessageComposeView(
                recipients: [person.phoneNumber ?? ""],
                body: message
            ) { result in
                showMessageCompose = false
                if result == .sent {
                    celebrateAndClose(recording: isBelated ? .belatedSent : .sent)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            let settings = AppSettings.fetchOrCreate(in: context)
            message = isBelated
                ? MessageTemplate.belatedMessage(for: person)
                : MessageTemplate.birthdayMessage(for: person, settings: settings)
        }
    }

    private var contextLine: String {
        if isBelated {
            return "Belated wishes still count 🎉"
        }
        if let age = person.nextOccurrence()?.ageTurning {
            return "Happy \(age)th birthday"
        }
        return "It's their day 🎂"
    }

    // MARK: - Buttons

    @ViewBuilder
    private var primaryButton: some View {
        if canText {
            Button {
                showMessageCompose = true
            } label: {
                Label("Send text", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            VStack(spacing: 8) {
                Button {
                    UIPasteboard.general.string = message
                    copiedToClipboard = true
                    Haptics.tap()
                } label: {
                    Label(copiedToClipboard ? "Copied!" : "Copy message", systemImage: "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if person.phoneNumber?.isEmpty != false {
                    Text("Add a phone number to text \(person.firstName) directly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var secondaryOptions: some View {
        HStack(spacing: 10) {
            if let phone = person.phoneNumber, !phone.isEmpty {
                secondaryButton("Add money", symbol: "dollarsign.circle") {
                    openVenmo(phone: phone)
                }
            }
            secondaryButton("Mark as done", symbol: "checkmark.circle") {
                celebrateAndClose(recording: isBelated ? .belatedSent : .sent)
            }
            secondaryButton("Skip this year", symbol: "forward.circle") {
                recordOutcome(.dismissed)
                dismiss()
            }
        }
    }

    private func secondaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openVenmo(phone: String) {
        if let venmo = WishoLinks.venmoPay(phone: phone),
           UIApplication.shared.canOpenURL(venmo) {
            UIApplication.shared.open(venmo)
        } else {
            UIApplication.shared.open(WishoLinks.venmoAppStore)
        }
    }

    private func recordOutcome(_ type: WishEventType) {
        // The occurrence being handled: the passed one for belated, the
        // imminent/today one otherwise.
        let occurrence = isBelated ? person.lastOccurrence() : person.nextOccurrence()
        person.lastWishedYear = occurrence?.year ?? Calendar.current.component(.year, from: .now)
        context.insert(WishEvent(personId: person.id, date: .now, type: type))
        try? context.save()
        // Reschedule so the pending Belated Rescue for this birthday is cancelled.
        Task { await Maintenance.run(context: context, isPro: store.isPro) }
    }

    private func celebrateAndClose(recording type: WishEventType) {
        recordOutcome(type)
        Haptics.success()
        isClosing = true
        withAnimation { showConfetti = true }
        let isFirstSend = !UserDefaults.standard.bool(forKey: "hasSentFirstWish")
        UserDefaults.standard.set(true, forKey: "hasSentFirstWish")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            dismiss()
            // Soft PRO prompt after the first successful send.
            if isFirstSend && !store.isPro {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AppRouter.shared.showPostSendPaywall = true
                }
            }
        }
    }
}
