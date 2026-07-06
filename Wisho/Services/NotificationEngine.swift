import Foundation
import UserNotifications

@MainActor
final class NotificationEngine {
    static let shared = NotificationEngine()
    private let center = UNUserNotificationCenter.current()

    enum Category {
        static let birthday = "WISHO_BIRTHDAY"
        static let rescue = "WISHO_RESCUE"
    }

    enum Kind: String {
        case headsUp
        case birthday
        case rescue
    }

    enum UserInfoKey {
        static let personId = "personId"
        static let kind = "kind"
    }

    /// iOS caps pending local notifications at 64 — keep headroom.
    private let maxPending = 60

    private init() {}

    func registerCategories() {
        let birthday = UNNotificationCategory(
            identifier: Category.birthday, actions: [], intentIdentifiers: [], options: []
        )
        let rescue = UNNotificationCategory(
            identifier: Category.rescue, actions: [], intentIdentifiers: [], options: []
        )
        center.setNotificationCategories([birthday, rescue])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Full reschedule: wipe everything pending and rebuild from current data.
    /// Called on launch, foreground, and after any data change — this is also
    /// how pending rescues get cancelled once a birthday is handled.
    func rescheduleAll(people: [Person], settings: AppSettings, isPro: Bool) async {
        center.removeAllPendingNotificationRequests()

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let now = Date.now
        var candidates: [(fireDate: Date, request: UNNotificationRequest)] = []

        for person in people where person.isEnabled {
            let tz = person.timeZone
            let cal = BirthdayMath.calendar(in: tz)

            if let fire = BirthdayMath.nextFireDate(
                month: person.birthMonth, day: person.birthDay,
                hour: settings.defaultSendHour, minute: settings.defaultSendMinute,
                timeZone: tz, after: now
            ) {
                // Day-of — skip if this year's birthday was already handled early.
                if person.lastWishedYear != fire.year {
                    let content = makeContent(
                        title: "🎂 It's \(person.firstName)'s birthday!",
                        body: "Tap to send your wish.",
                        category: Category.birthday,
                        kind: .birthday,
                        person: person
                    )
                    candidates.append((fire.date, request(id: "birthday-\(person.id)-\(fire.year)", content: content, fireDate: fire.date, timeZone: tz)))
                }

                // Heads-up N days before (PRO).
                if isPro, person.reminderLeadDays > 0,
                   let leadDate = cal.date(byAdding: .day, value: -person.reminderLeadDays, to: fire.date),
                   leadDate > now {
                    let content = makeContent(
                        title: "🎁 \(person.firstName)'s birthday is in \(person.reminderLeadDays) \(person.reminderLeadDays == 1 ? "day" : "days")",
                        body: "Get a wish ready.",
                        category: Category.birthday,
                        kind: .headsUp,
                        person: person
                    )
                    candidates.append((leadDate, request(id: "lead-\(person.id)-\(fire.year)", content: content, fireDate: leadDate, timeZone: tz)))
                }

                // Belated Rescue for the upcoming occurrence, pre-scheduled now
                // because the app may not run again before the birthday. The
                // full reschedule after a send/dismiss cancels it.
                if isPro, settings.belatedRescueEnabled, person.lastWishedYear != fire.year,
                   let rescue = rescueDate(afterBirthday: fire.date, timeZone: tz), rescue > now {
                    candidates.append((rescue, request(id: "rescue-\(person.id)-\(fire.year)", content: rescueContent(for: person), fireDate: rescue, timeZone: tz)))
                }
            }

            // Belated Rescue for a recently passed, still-unhandled birthday
            // (covers birthdays missed while the rescue hadn't fired yet).
            if isPro, settings.belatedRescueEnabled,
               let missed = person.missedOccurrence(),
               let rescue = rescueDate(afterBirthday: missed.date, timeZone: tz),
               rescue > now {
                candidates.append((rescue, request(id: "rescue-\(person.id)-\(missed.year)", content: rescueContent(for: person), fireDate: rescue, timeZone: tz)))
            }
        }

        for item in candidates.sorted(by: { $0.fireDate < $1.fireDate }).prefix(maxPending) {
            try? await center.add(item.request)
        }
    }

    // MARK: - Builders

    private func rescueContent(for person: Person) -> UNMutableNotificationContent {
        makeContent(
            title: "You missed \(person.firstName)'s birthday 😬",
            body: "Send a belated message — it still counts.",
            category: Category.rescue,
            kind: .rescue,
            person: person
        )
    }

    private func makeContent(
        title: String, body: String,
        category: String, kind: Kind, person: Person
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = [
            UserInfoKey.personId: person.id.uuidString,
            UserInfoKey.kind: kind.rawValue
        ]
        return content
    }

    /// Two days after the birthday, at 10:00 AM local to the person.
    private func rescueDate(afterBirthday day: Date, timeZone: TimeZone) -> Date? {
        let cal = BirthdayMath.calendar(in: timeZone)
        guard let twoDaysLater = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: day)) else { return nil }
        return cal.date(bySettingHour: 10, minute: 0, second: 0, of: twoDaysLater)
    }

    private func request(
        id: String, content: UNMutableNotificationContent,
        fireDate: Date, timeZone: TimeZone
    ) -> UNNotificationRequest {
        let cal = BirthdayMath.calendar(in: timeZone)
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        comps.timeZone = timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
