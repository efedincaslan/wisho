import SwiftUI

/// Loud, celebratory card for today's birthdays — the money moment.
struct TodayCard: View {
    let person: Person
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AvatarView(person: person, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("It's \(person.firstName)'s birthday! 🎂")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let age = person.nextOccurrence()?.ageTurning {
                        Text("Turning \(age) today")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
            Button(action: onSend) {
                Text("Send your wish")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

/// Amber-accented rescue card for missed birthdays.
struct MissedCard: View {
    let person: Person
    let occurrence: BirthdayOccurrence
    let onSendBelated: () -> Void

    private var daysAgo: Int {
        Calendar.current.dateComponents(
            [.day], from: occurrence.date, to: Calendar.current.startOfDay(for: .now)
        ).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(person: person, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You missed \(person.firstName)'s birthday")
                        .font(.subheadline.weight(.semibold))
                    Text(daysAgo == 1 ? "Yesterday" : "\(daysAgo) days ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Button(action: onSendBelated) {
                Text("Send belated wish — it still counts")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.35))
                )
        )
    }
}

/// Standard upcoming-birthday row.
struct PersonRow: View {
    let person: Person
    let occurrence: BirthdayOccurrence

    private var daysAway: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: occurrence.date).day ?? 0
    }

    private var whenLabel: String {
        switch daysAway {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "in \(daysAway) days"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(person: person, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.fullName)
                    .font(.body)
                if let age = occurrence.ageTurning {
                    Text("turns \(age)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(occurrence.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.subheadline.weight(.medium))
                Text(whenLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
