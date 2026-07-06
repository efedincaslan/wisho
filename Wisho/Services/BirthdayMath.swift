import Foundation

/// A concrete celebration of a birthday in a specific year.
struct BirthdayOccurrence {
    /// Start of the celebrated day in the relevant timezone.
    let date: Date
    /// Calendar year of the occurrence.
    let year: Int
    /// Age the person turns on this occurrence, if their birth year is known.
    let ageTurning: Int?
}

enum BirthdayMath {

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// Feb 29 birthdays are celebrated on Feb 28 in non-leap years.
    static func resolvedDay(month: Int, day: Int, inYear year: Int) -> Int {
        (month == 2 && day == 29 && !isLeapYear(year)) ? 28 : day
    }

    static func calendar(in timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    static func occurrenceDate(
        month: Int, day: Int, year: Int,
        hour: Int = 0, minute: Int = 0,
        timeZone: TimeZone
    ) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = resolvedDay(month: month, day: day, inYear: year)
        comps.hour = hour
        comps.minute = minute
        return calendar(in: timeZone).date(from: comps)
    }

    /// First occurrence whose celebrated *day* is today or later (today's
    /// birthday still counts as the next occurrence).
    static func nextOccurrence(
        month: Int, day: Int, birthYear: Int?,
        timeZone: TimeZone, after reference: Date = .now
    ) -> BirthdayOccurrence? {
        let cal = calendar(in: timeZone)
        let startOfToday = cal.startOfDay(for: reference)
        let currentYear = cal.component(.year, from: reference)
        for year in currentYear...(currentYear + 1) {
            guard let date = occurrenceDate(month: month, day: day, year: year, timeZone: timeZone) else { continue }
            if date >= startOfToday {
                return BirthdayOccurrence(date: date, year: year, ageTurning: birthYear.map { year - $0 })
            }
        }
        return nil
    }

    /// Most recent occurrence strictly before today.
    static func lastOccurrence(
        month: Int, day: Int, birthYear: Int?,
        timeZone: TimeZone, before reference: Date = .now
    ) -> BirthdayOccurrence? {
        let cal = calendar(in: timeZone)
        let startOfToday = cal.startOfDay(for: reference)
        let currentYear = cal.component(.year, from: reference)
        for year in [currentYear, currentYear - 1] {
            guard let date = occurrenceDate(month: month, day: day, year: year, timeZone: timeZone) else { continue }
            if date < startOfToday {
                return BirthdayOccurrence(date: date, year: year, ageTurning: birthYear.map { year - $0 })
            }
        }
        return nil
    }

    /// Exact moment the day-of notification should fire. Skips fire times that
    /// have already passed — a timezone-set person whose send time went by
    /// rolls to next year instead of firing immediately.
    static func nextFireDate(
        month: Int, day: Int,
        hour: Int, minute: Int,
        timeZone: TimeZone, after reference: Date = .now
    ) -> (date: Date, year: Int)? {
        let cal = calendar(in: timeZone)
        let currentYear = cal.component(.year, from: reference)
        for year in currentYear...(currentYear + 1) {
            if let date = occurrenceDate(month: month, day: day, year: year, hour: hour, minute: minute, timeZone: timeZone),
               date > reference {
                return (date, year)
            }
        }
        return nil
    }
}

extension Person {

    var timeZone: TimeZone {
        timezoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    func nextOccurrence(after reference: Date = .now) -> BirthdayOccurrence? {
        BirthdayMath.nextOccurrence(
            month: birthMonth, day: birthDay, birthYear: birthYear,
            timeZone: timeZone, after: reference
        )
    }

    func lastOccurrence(before reference: Date = .now) -> BirthdayOccurrence? {
        BirthdayMath.lastOccurrence(
            month: birthMonth, day: birthDay, birthYear: birthYear,
            timeZone: timeZone, before: reference
        )
    }

    var isBirthdayToday: Bool {
        guard let next = nextOccurrence() else { return false }
        return BirthdayMath.calendar(in: timeZone).isDateInToday(next.date)
    }

    /// An unhandled birthday in the recent past — the Belated Rescue window.
    func missedOccurrence(withinDays window: Int = 14, reference: Date = .now) -> BirthdayOccurrence? {
        guard let last = lastOccurrence(before: reference) else { return nil }
        guard lastWishedYear != last.year else { return nil }
        let cal = BirthdayMath.calendar(in: timeZone)
        let days = cal.dateComponents([.day], from: last.date, to: reference).day ?? .max
        return days <= window ? last : nil
    }
}
