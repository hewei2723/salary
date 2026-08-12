import Foundation
import Testing
@testable import SalaryCharger

struct EarningsCalculatorTests {
    @Test func calculatesEarningsForElapsedTime() {
        let result = EarningsCalculator.earned(hourlyRate: 120, elapsed: 30)
        #expect(abs(result - 1) < 0.000_001)
    }

    @Test func rejectsNegativeInput() {
        #expect(EarningsCalculator.earned(hourlyRate: -1, elapsed: 30) == 0)
        #expect(EarningsCalculator.earned(hourlyRate: 100, elapsed: -1) == 0)
    }

    @Test func createsStableCalendarMonthKey() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let date = try #require(
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: 10
            ).date
        )

        #expect(EarningsCalculator.monthKey(for: date, calendar: calendar) == "2026-08")
        #expect(EarningsCalculator.dayKey(for: date, calendar: calendar) == "2026-08-10")
    }

    @Test func calculatesTotalsFromWorkSchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let schedule = try schedule(calendar: calendar)
        let date = try #require(
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: 11,
                hour: 12
            ).date
        )

        let totals = EarningsCalculator.calendarTotals(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [],
            schedule: schedule,
            at: date,
            calendar: calendar
        )

        #expect(abs(totals.day - 250) < 0.000_001)
        #expect(abs(totals.month - 5_850) < 0.000_001)
    }

    @Test func appliesSmallWeekAndOvertimeRules() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let schedule = try schedule(calendar: calendar)

        func date(day: Int, hour: Int = 12) throws -> Date {
            try #require(
                DateComponents(
                    calendar: calendar,
                    timeZone: calendar.timeZone,
                    year: 2026,
                    month: 8,
                    day: day,
                    hour: hour
                ).date
            )
        }

        #expect(
            EarningsCalculator.isSmallSaturday(
                try date(day: 15),
                anchor: schedule.smallWeekAnchor,
                calendar: calendar
            )
        )
        #expect(
            !EarningsCalculator.isSmallSaturday(
                try date(day: 8),
                anchor: schedule.smallWeekAnchor,
                calendar: calendar
            )
        )
        #expect(
            EarningsCalculator.isSmallSaturday(
                try date(day: 1),
                anchor: schedule.smallWeekAnchor,
                calendar: calendar
            )
        )

        let now = try date(day: 11)
        let overtimeSunday = EarningsCalculator.dayKey(
            for: try date(day: 9),
            calendar: calendar
        )
        let totals = EarningsCalculator.calendarTotals(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [overtimeSunday],
            schedule: schedule,
            at: now,
            calendar: calendar
        )

        #expect(abs(totals.month - 6_250) < 0.000_001)
    }

    @Test func addsOvertimeWindowAfterRegularShift() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let schedule = try schedule(calendar: calendar)
        let now = try #require(
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: 11,
                hour: 19,
                minute: 30
            ).date
        )
        let overtimeDay = EarningsCalculator.dayKey(for: now, calendar: calendar)

        let totals = EarningsCalculator.calendarTotals(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [overtimeDay],
            schedule: schedule,
            at: now,
            calendar: calendar
        )

        #expect(abs(totals.day - 1_000) < 0.000_001)
        #expect(abs(totals.month - 6_600) < 0.000_001)
    }

    @Test func supportsDoubleSingleAndAlternatingWeekendRules() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        var schedule = try schedule(calendar: calendar)

        func date(day: Int) throws -> Date {
            try #require(
                DateComponents(
                    calendar: calendar,
                    timeZone: calendar.timeZone,
                    year: 2026,
                    month: 8,
                    day: day
                ).date
            )
        }

        schedule.workweekRule = .doubleWeekend
        #expect(
            !EarningsCalculator.isRegularWorkday(
                try date(day: 15),
                schedule: schedule,
                calendar: calendar
            )
        )

        schedule.workweekRule = .singleWeekend
        #expect(
            EarningsCalculator.isRegularWorkday(
                try date(day: 15),
                schedule: schedule,
                calendar: calendar
            )
        )
        #expect(
            !EarningsCalculator.isRegularWorkday(
                try date(day: 16),
                schedule: schedule,
                calendar: calendar
            )
        )

        schedule.workweekRule = .alternatingWeek
        #expect(
            EarningsCalculator.isRegularWorkday(
                try date(day: 15),
                schedule: schedule,
                calendar: calendar
            )
        )
        #expect(
            !EarningsCalculator.isRegularWorkday(
                try date(day: 8),
                schedule: schedule,
                calendar: calendar
            )
        )
    }

    @Test func excludesConfiguredLunchBreak() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let schedule = try schedule(calendar: calendar)
        let duringLunch = try #require(
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: 11,
                hour: 12,
                minute: 30
            ).date
        )

        let totals = EarningsCalculator.calendarTotals(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [],
            schedule: schedule,
            at: duringLunch,
            calendar: calendar
        )

        #expect(abs(totals.day - 250) < 0.000_001)
    }

    @Test func calculatesSelectedPastTodayAndFutureDayEarnings() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let schedule = try schedule(calendar: calendar)

        func date(day: Int, hour: Int = 0) throws -> Date {
            try #require(
                DateComponents(
                    calendar: calendar,
                    timeZone: calendar.timeZone,
                    year: 2026,
                    month: 8,
                    day: day,
                    hour: hour
                ).date
            )
        }

        let now = try date(day: 12, hour: 12)
        let overtimeDay = try date(day: 11)
        let overtimeKey = EarningsCalculator.dayKey(for: overtimeDay, calendar: calendar)

        let past = EarningsCalculator.dailyEarnings(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [overtimeKey],
            schedule: schedule,
            on: overtimeDay,
            at: now,
            calendar: calendar
        )
        let today = EarningsCalculator.dailyEarnings(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [],
            schedule: schedule,
            on: now,
            at: now,
            calendar: calendar
        )
        let future = EarningsCalculator.dailyEarnings(
            hourlyRate: 100,
            overtimeRate: 200,
            overtimeDays: [],
            schedule: schedule,
            on: try date(day: 13),
            at: now,
            calendar: calendar
        )

        #expect(abs(past - 1_200) < 0.000_001)
        #expect(abs(today - 250) < 0.000_001)
        #expect(future == 0)
    }

    private func schedule(calendar: Calendar) throws -> WorkSchedule {
        let anchor = try #require(
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: 15
            ).date
        )
        return WorkSchedule(
            workStartMinutes: 9 * 60 + 30,
            workEndMinutes: 18 * 60 + 30,
            lunchStartMinutes: 12 * 60,
            lunchEndMinutes: 13 * 60,
            overtimeStartMinutes: 18 * 60 + 30,
            overtimeEndMinutes: 20 * 60 + 30,
            workweekRule: .alternatingWeek,
            smallWeekAnchor: anchor
        )
    }
}
