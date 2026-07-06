import XCTest
@testable import Wisho

final class BirthdayMathTests: XCTestCase {

    private let tz = TimeZone(identifier: "America/New_York")!
    private var cal: Calendar { BirthdayMath.calendar(in: tz) }

    /// Noon on the given day, in the test timezone.
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Leap years

    func testLeapYears() {
        XCTAssertTrue(BirthdayMath.isLeapYear(2024))
        XCTAssertFalse(BirthdayMath.isLeapYear(2025))
        XCTAssertTrue(BirthdayMath.isLeapYear(2000))
        XCTAssertFalse(BirthdayMath.isLeapYear(1900))
    }

    func testFeb29CelebratedOnFeb28InNonLeapYears() {
        XCTAssertEqual(BirthdayMath.resolvedDay(month: 2, day: 29, inYear: 2025), 28)
        XCTAssertEqual(BirthdayMath.resolvedDay(month: 2, day: 29, inYear: 2024), 29)
        // Non-Feb-29 days are untouched.
        XCTAssertEqual(BirthdayMath.resolvedDay(month: 2, day: 28, inYear: 2025), 28)
        XCTAssertEqual(BirthdayMath.resolvedDay(month: 7, day: 29, inYear: 2025), 29)
    }

    func testFeb29NextOccurrenceInNonLeapYear() {
        let ref = date(2026, 1, 15)
        let next = BirthdayMath.nextOccurrence(month: 2, day: 29, birthYear: 2000, timeZone: tz, after: ref)
        XCTAssertEqual(next?.year, 2026)
        let comps = cal.dateComponents([.month, .day], from: next!.date)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 28)
    }

    // MARK: - Next occurrence

    func testBirthdayTodayCountsAsNextOccurrence() {
        let ref = date(2026, 7, 6)
        let next = BirthdayMath.nextOccurrence(month: 7, day: 6, birthYear: 1990, timeZone: tz, after: ref)
        XCTAssertEqual(next?.year, 2026)
        XCTAssertEqual(next?.ageTurning, 36)
    }

    func testBirthdayYesterdayRollsToNextYear() {
        let ref = date(2026, 7, 6)
        let next = BirthdayMath.nextOccurrence(month: 7, day: 5, birthYear: 1990, timeZone: tz, after: ref)
        XCTAssertEqual(next?.year, 2027)
        XCTAssertEqual(next?.ageTurning, 37)
    }

    func testUnknownBirthYearHidesAge() {
        let ref = date(2026, 7, 6)
        let next = BirthdayMath.nextOccurrence(month: 8, day: 1, birthYear: nil, timeZone: tz, after: ref)
        XCTAssertNil(next?.ageTurning)
    }

    // MARK: - Last occurrence

    func testLastOccurrenceEarlierThisYear() {
        let ref = date(2026, 7, 6)
        let last = BirthdayMath.lastOccurrence(month: 7, day: 5, birthYear: nil, timeZone: tz, before: ref)
        XCTAssertEqual(last?.year, 2026)
    }

    func testLastOccurrenceCrossesYearBoundary() {
        let ref = date(2026, 1, 2)
        let last = BirthdayMath.lastOccurrence(month: 12, day: 30, birthYear: nil, timeZone: tz, before: ref)
        XCTAssertEqual(last?.year, 2025)
    }

    func testTodayIsNotALastOccurrence() {
        let ref = date(2026, 7, 6)
        let last = BirthdayMath.lastOccurrence(month: 7, day: 6, birthYear: nil, timeZone: tz, before: ref)
        XCTAssertEqual(last?.year, 2025)
    }

    // MARK: - Fire dates

    func testPassedSendTimeRollsToNextYear() {
        // Reference is noon; the 9 AM slot today has already passed.
        let ref = date(2026, 7, 6, hour: 12)
        let fire = BirthdayMath.nextFireDate(month: 7, day: 6, hour: 9, minute: 0, timeZone: tz, after: ref)
        XCTAssertEqual(fire?.year, 2027)
    }

    func testUpcomingSendTimeTodayFiresToday() {
        let ref = date(2026, 7, 6, hour: 8)
        let fire = BirthdayMath.nextFireDate(month: 7, day: 6, hour: 9, minute: 0, timeZone: tz, after: ref)
        XCTAssertEqual(fire?.year, 2026)
    }

    // MARK: - Missed window (Belated Rescue)

    func testUnhandledRecentBirthdayIsMissed() {
        let ref = date(2026, 7, 6)
        let person = Person(firstName: "Test", birthMonth: 7, birthDay: 3)
        XCTAssertNotNil(person.missedOccurrence(reference: ref))
    }

    func testHandledBirthdayIsNotMissed() {
        let ref = date(2026, 7, 6)
        let person = Person(firstName: "Test", birthMonth: 7, birthDay: 3, lastWishedYear: 2026)
        XCTAssertNil(person.missedOccurrence(reference: ref))
    }

    func testOldMissesFallOutOfTheWindow() {
        let ref = date(2026, 7, 6)
        let person = Person(firstName: "Test", birthMonth: 6, birthDay: 1)
        XCTAssertNil(person.missedOccurrence(withinDays: 14, reference: ref))
    }
}
