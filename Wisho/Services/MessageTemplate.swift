import Foundation

enum MessageTemplate {
    static let firstNameToken = "{first_name}"
    static let defaultBirthday = "happy birthday {first_name}! 🎂"
    static let belated = "hey {first_name}! belated happy birthday 🎉 hope it was a great one"

    static func render(_ template: String, firstName: String) -> String {
        template.replacingOccurrences(of: firstNameToken, with: firstName)
    }

    static func birthdayMessage(for person: Person, settings: AppSettings) -> String {
        render(person.customMessage ?? settings.defaultMessageTemplate, firstName: person.firstName)
    }

    static func belatedMessage(for person: Person) -> String {
        render(belated, firstName: person.firstName)
    }
}
