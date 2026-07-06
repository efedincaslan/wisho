import Foundation
import SwiftData

/// Demo data for UI-test runs (`--uitesting` launch argument) so screenshots
/// show every Home section: today, missed, coming up, and later.
@MainActor
enum UITestSeed {

    static func populateIfNeeded(context: ModelContext) {
        guard (try? context.fetch(FetchDescriptor<Person>()))?.isEmpty ?? true else { return }

        let cal = Calendar.current
        let now = Date.now

        func monthDay(daysFromNow offset: Int) -> (month: Int, day: Int) {
            let date = cal.date(byAdding: .day, value: offset, to: now) ?? now
            let comps = cal.dateComponents([.month, .day], from: date)
            return (comps.month ?? 1, comps.day ?? 1)
        }

        let today = monthDay(daysFromNow: 0)
        context.insert(Person(
            firstName: "Maya", lastName: "Chen",
            birthMonth: today.month, birthDay: today.day, birthYear: 1996,
            phoneNumber: "+15551234567", source: .manual
        ))

        let missed = monthDay(daysFromNow: -3)
        context.insert(Person(
            firstName: "Dad",
            birthMonth: missed.month, birthDay: missed.day, birthYear: 1958,
            phoneNumber: "+15559876543", source: .manual
        ))

        let soon = monthDay(daysFromNow: 5)
        context.insert(Person(
            firstName: "Sam", lastName: "Rivera",
            birthMonth: soon.month, birthDay: soon.day,
            source: .manual
        ))

        let nextWeek = monthDay(daysFromNow: 12)
        context.insert(Person(
            firstName: "June", lastName: "Park",
            birthMonth: nextWeek.month, birthDay: nextWeek.day, birthYear: 1990,
            phoneNumber: "+15550001111", source: .manual
        ))

        let later = monthDay(daysFromNow: 45)
        context.insert(Person(
            firstName: "Lena", lastName: "Kowalski",
            birthMonth: later.month, birthDay: later.day, birthYear: 1992,
            phoneNumber: "+15552223333", source: .manual
        ))

        try? context.save()
    }
}
