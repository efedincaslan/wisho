import WidgetKit
import SwiftUI
import SwiftData

@main
struct WishoWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpcomingBirthdaysWidget()
    }
}

struct UpcomingBirthdaysWidget: Widget {
    let kind = "UpcomingBirthdays"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayProvider()) { entry in
            UpcomingBirthdaysView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Upcoming Birthdays")
        .description("Never miss the next one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct WidgetBirthday: Identifiable {
    let id: UUID
    let name: String
    let photoData: Data?
    let daysAway: Int
    let dateLabel: String
}

struct BirthdayEntry: TimelineEntry {
    let date: Date
    let isPro: Bool
    let birthdays: [WidgetBirthday]
}

struct BirthdayProvider: TimelineProvider {

    func placeholder(in context: Context) -> BirthdayEntry {
        BirthdayEntry(date: .now, isPro: true, birthdays: [
            WidgetBirthday(id: UUID(), name: "Maya", photoData: nil, daysAway: 0, dateLabel: "Today"),
            WidgetBirthday(id: UUID(), name: "Dad", photoData: nil, daysAway: 3, dateLabel: "in 3 days"),
            WidgetBirthday(id: UUID(), name: "Sam", photoData: nil, daysAway: 12, dateLabel: "in 12 days")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh at the next local midnight so day counts roll over.
        let cal = Calendar.current
        let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now) ?? .now)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func loadEntry() -> BirthdayEntry {
        let isPro = UserDefaults(suiteName: AppGroup.identifier)?.bool(forKey: AppGroup.isProKey) ?? false
        guard isPro else {
            return BirthdayEntry(date: .now, isPro: false, birthdays: [])
        }

        do {
            let schema = Schema([Person.self, WishEvent.self, AppSettings.self])
            let config = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.identifier))
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let people = try context.fetch(FetchDescriptor<Person>())

            let cal = Calendar.current
            let startOfToday = cal.startOfDay(for: .now)

            let upcoming = people
                .filter(\.isEnabled)
                .compactMap { person -> WidgetBirthday? in
                    guard let occurrence = person.nextOccurrence() else { return nil }
                    let days = cal.dateComponents([.day], from: startOfToday, to: occurrence.date).day ?? 0
                    let label: String
                    switch days {
                    case 0: label = "Today 🎂"
                    case 1: label = "Tomorrow"
                    default: label = "in \(days) days"
                    }
                    return WidgetBirthday(
                        id: person.id,
                        name: person.firstName,
                        photoData: person.photoData,
                        daysAway: days,
                        dateLabel: label
                    )
                }
                .sorted { $0.daysAway < $1.daysAway }
                .prefix(3)

            return BirthdayEntry(date: .now, isPro: true, birthdays: Array(upcoming))
        } catch {
            return BirthdayEntry(date: .now, isPro: true, birthdays: [])
        }
    }
}

// MARK: - Views

struct UpcomingBirthdaysView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirthdayEntry

    var body: some View {
        if !entry.isPro {
            lockedView
        } else if entry.birthdays.isEmpty {
            emptyView
        } else if family == .systemSmall {
            smallView
        } else {
            mediumView
        }
    }

    private var lockedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text("Widget is a Wisho PRO feature")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "gift")
                .foregroundStyle(.secondary)
            Text("No birthdays yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var smallView: some View {
        let next = entry.birthdays[0]
        return VStack(alignment: .leading, spacing: 8) {
            WidgetAvatar(name: next.name, photoData: next.photoData, size: 40)
            Spacer(minLength: 0)
            Text(next.name)
                .font(.headline)
                .lineLimit(1)
            Text(next.dateLabel)
                .font(.subheadline)
                .foregroundStyle(next.daysAway == 0 ? .pink : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entry.birthdays) { birthday in
                HStack(spacing: 10) {
                    WidgetAvatar(name: birthday.name, photoData: birthday.photoData, size: 30)
                    Text(birthday.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text(birthday.dateLabel)
                        .font(.caption)
                        .foregroundStyle(birthday.daysAway == 0 ? .pink : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WidgetAvatar: View {
    let name: String
    let photoData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.pink.opacity(0.8)
                    Text(name.first.map(String.init)?.uppercased() ?? "?")
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
