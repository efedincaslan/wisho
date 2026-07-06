import Foundation
import SwiftData

enum PersonSource: String, Codable {
    case contacts
    case manual
}

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String?

    // Birthday stored as split fields so SwiftData can persist and query them
    // directly. Year is optional — CNContact birthdays frequently omit it.
    var birthMonth: Int
    var birthDay: Int
    var birthYear: Int?

    var phoneNumber: String?
    var contactIdentifier: String?
    @Attribute(.externalStorage) var photoData: Data?
    var timezoneIdentifier: String?
    var reminderLeadDays: Int
    var isEnabled: Bool
    var customMessage: String?
    var lastWishedYear: Int?
    private var sourceRaw: String

    var source: PersonSource {
        get { PersonSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String? = nil,
        birthMonth: Int,
        birthDay: Int,
        birthYear: Int? = nil,
        phoneNumber: String? = nil,
        contactIdentifier: String? = nil,
        photoData: Data? = nil,
        timezoneIdentifier: String? = nil,
        reminderLeadDays: Int = 0,
        isEnabled: Bool = true,
        customMessage: String? = nil,
        lastWishedYear: Int? = nil,
        source: PersonSource = .manual
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        self.birthYear = birthYear
        self.phoneNumber = phoneNumber
        self.contactIdentifier = contactIdentifier
        self.photoData = photoData
        self.timezoneIdentifier = timezoneIdentifier
        self.reminderLeadDays = reminderLeadDays
        self.isEnabled = isEnabled
        self.customMessage = customMessage
        self.lastWishedYear = lastWishedYear
        self.sourceRaw = source.rawValue
    }
}

extension Person {
    var fullName: String {
        if let lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        }
        return firstName
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        let combined = first + last
        return combined.isEmpty ? "?" : combined.uppercased()
    }

    var birthday: DateComponents {
        DateComponents(year: birthYear, month: birthMonth, day: birthDay)
    }
}
