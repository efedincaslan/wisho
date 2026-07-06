import Foundation
import Contacts
import SwiftData

struct SyncResult {
    var imported = 0
    var updated = 0
    /// Contacts that could not be imported because the free tier is full.
    var skippedForLimit = 0
}

enum ContactSyncService {

    struct ImportedContact {
        let identifier: String
        let givenName: String
        let familyName: String
        let month: Int
        let day: Int
        let year: Int?
        let phone: String?
        let photo: Data?
    }

    static func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        return (try? await store.requestAccess(for: .contacts)) ?? false
    }

    /// Imports/updates all contacts that have a birthday set.
    /// Matching is by CNContact identifier: existing people update in place
    /// (never duplicated), manual entries are never touched or deleted.
    @MainActor
    static func sync(context: ModelContext, isPro: Bool) async throws -> SyncResult {
        let contacts = try await fetchBirthdayContacts()
        let existing = try context.fetch(FetchDescriptor<Person>())

        var byIdentifier: [String: Person] = [:]
        for person in existing {
            if let cid = person.contactIdentifier {
                byIdentifier[cid] = person
            }
        }

        var result = SyncResult()
        var totalCount = existing.count

        for contact in contacts {
            if let person = byIdentifier[contact.identifier] {
                person.firstName = contact.givenName.isEmpty ? person.firstName : contact.givenName
                person.lastName = contact.familyName.isEmpty ? person.lastName : contact.familyName
                person.birthMonth = contact.month
                person.birthDay = contact.day
                person.birthYear = contact.year
                if let phone = contact.phone { person.phoneNumber = phone }
                if let photo = contact.photo { person.photoData = photo }
                result.updated += 1
            } else {
                guard isPro || totalCount < StoreManager.freePersonLimit else {
                    result.skippedForLimit += 1
                    continue
                }
                let name = contact.givenName.isEmpty
                    ? (contact.familyName.isEmpty ? "Someone" : contact.familyName)
                    : contact.givenName
                let person = Person(
                    firstName: name,
                    lastName: contact.givenName.isEmpty ? nil : (contact.familyName.isEmpty ? nil : contact.familyName),
                    birthMonth: contact.month,
                    birthDay: contact.day,
                    birthYear: contact.year,
                    phoneNumber: contact.phone,
                    contactIdentifier: contact.identifier,
                    photoData: contact.photo,
                    source: .contacts
                )
                context.insert(person)
                totalCount += 1
                result.imported += 1
            }
        }

        try context.save()
        return result
    }

    private static func fetchBirthdayContacts() async throws -> [ImportedContact] {
        try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactBirthdayKey,
                CNContactPhoneNumbersKey,
                CNContactThumbnailImageDataKey
            ] as [CNKeyDescriptor]

            let request = CNContactFetchRequest(keysToFetch: keys)
            var results: [ImportedContact] = []

            try store.enumerateContacts(with: request) { contact, _ in
                guard let birthday = contact.birthday,
                      let month = birthday.month,
                      let day = birthday.day else { return }
                results.append(ImportedContact(
                    identifier: contact.identifier,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    month: month,
                    day: day,
                    year: normalizedYear(birthday.year),
                    phone: preferredPhoneNumber(from: contact.phoneNumbers),
                    photo: contact.thumbnailImageData
                ))
            }
            return results
        }.value
    }

    /// Contacts encodes "no year" either as nil or as the Gregorian reference
    /// year 1604 — treat anything implausible as unknown.
    private static func normalizedYear(_ year: Int?) -> Int? {
        guard let year, year > 1900 else { return nil }
        return year
    }

    private static func preferredPhoneNumber(from numbers: [CNLabeledValue<CNPhoneNumber>]) -> String? {
        guard !numbers.isEmpty else { return nil }
        let preferredLabels = [CNLabelPhoneNumberMobile, CNLabelPhoneNumberiPhone, CNLabelPhoneNumberMain]
        let pick = preferredLabels
            .compactMap { label in numbers.first { $0.label == label } }
            .first ?? numbers[0]
        return normalizePhone(pick.value.stringValue)
    }

    /// Light E.164-ish cleanup: keep digits plus a leading "+" if present.
    static func normalizePhone(_ raw: String) -> String {
        let hasPlus = raw.hasPrefix("+")
        let digits = raw.filter(\.isNumber)
        return hasPlus ? "+\(digits)" : digits
    }
}
