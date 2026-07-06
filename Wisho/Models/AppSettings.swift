import Foundation
import SwiftData

@Model
final class AppSettings {
    var defaultMessageTemplate: String
    var defaultSendHour: Int
    var defaultSendMinute: Int
    var belatedRescueEnabled: Bool
    var notificationsAuthorized: Bool

    init(
        defaultMessageTemplate: String = MessageTemplate.defaultBirthday,
        defaultSendHour: Int = 9,
        defaultSendMinute: Int = 0,
        belatedRescueEnabled: Bool = true,
        notificationsAuthorized: Bool = false
    ) {
        self.defaultMessageTemplate = defaultMessageTemplate
        self.defaultSendHour = defaultSendHour
        self.defaultSendMinute = defaultSendMinute
        self.belatedRescueEnabled = belatedRescueEnabled
        self.notificationsAuthorized = notificationsAuthorized
    }

    var defaultSendTime: DateComponents {
        DateComponents(hour: defaultSendHour, minute: defaultSendMinute)
    }

    static func fetchOrCreate(in context: ModelContext) -> AppSettings {
        if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
