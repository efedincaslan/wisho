import Foundation
import SwiftData
import WidgetKit

/// Housekeeping run on launch, foreground, and after any data change:
/// records missed birthdays, refreshes notification schedule and widget.
@MainActor
enum Maintenance {

    static func run(context: ModelContext, isPro: Bool) async {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let settings = AppSettings.fetchOrCreate(in: context)

        settings.notificationsAuthorized = await NotificationEngine.shared.authorizationStatus() == .authorized
        recordMissedEvents(people: people, context: context)
        try? context.save()

        await NotificationEngine.shared.rescheduleAll(people: people, settings: settings, isPro: isPro)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Log a `.missed` event once per unhandled passed birthday, so history
    /// stays honest even if the user never opens the rescue notification.
    static func recordMissedEvents(people: [Person], context: ModelContext) {
        let events = (try? context.fetch(FetchDescriptor<WishEvent>())) ?? []
        for person in people where person.isEnabled {
            guard let missed = person.missedOccurrence() else { continue }
            let alreadyLogged = events.contains { $0.personId == person.id && $0.date >= missed.date }
            if !alreadyLogged {
                context.insert(WishEvent(personId: person.id, date: missed.date, type: .missed))
            }
        }
    }
}
