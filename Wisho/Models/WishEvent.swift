import Foundation
import SwiftData

enum WishEventType: String, Codable, CaseIterable {
    case sent
    case dismissed
    case missed
    case belatedSent

    var label: String {
        switch self {
        case .sent: return "Wish sent"
        case .dismissed: return "Skipped"
        case .missed: return "Missed"
        case .belatedSent: return "Belated wish sent"
        }
    }

    var symbolName: String {
        switch self {
        case .sent: return "paperplane.fill"
        case .dismissed: return "forward.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .belatedSent: return "clock.arrow.circlepath"
        }
    }
}

@Model
final class WishEvent {
    @Attribute(.unique) var id: UUID
    var personId: UUID
    var date: Date
    private var typeRaw: String

    var type: WishEventType {
        get { WishEventType(rawValue: typeRaw) ?? .sent }
        set { typeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), personId: UUID, date: Date = .now, type: WishEventType) {
        self.id = id
        self.personId = personId
        self.date = date
        self.typeRaw = type.rawValue
    }
}
