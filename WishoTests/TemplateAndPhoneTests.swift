import XCTest
@testable import Wisho

final class TemplateAndPhoneTests: XCTestCase {

    func testFirstNameSubstitution() {
        XCTAssertEqual(
            MessageTemplate.render("happy birthday {first_name}! 🎂", firstName: "Maya"),
            "happy birthday Maya! 🎂"
        )
    }

    func testMultipleTokens() {
        XCTAssertEqual(
            MessageTemplate.render("{first_name} {first_name}!", firstName: "Sam"),
            "Sam Sam!"
        )
    }

    func testTemplateWithoutTokenIsUnchanged() {
        XCTAssertEqual(
            MessageTemplate.render("happy bday!", firstName: "Sam"),
            "happy bday!"
        )
    }

    func testCustomMessageOverridesDefault() {
        let settings = AppSettings()
        let person = Person(firstName: "June", birthMonth: 1, birthDay: 1, customMessage: "yo {first_name} 🎉")
        XCTAssertEqual(MessageTemplate.birthdayMessage(for: person, settings: settings), "yo June 🎉")
    }

    func testPhoneNormalizationKeepsLeadingPlus() {
        XCTAssertEqual(ContactSyncService.normalizePhone("+1 (555) 123-4567"), "+15551234567")
    }

    func testPhoneNormalizationStripsFormatting() {
        XCTAssertEqual(ContactSyncService.normalizePhone("0555 123 45 67"), "05551234567")
    }
}
