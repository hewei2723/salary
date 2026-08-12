import Foundation

enum WorkweekRule: String, CaseIterable, Equatable {
    case doubleWeekend
    case singleWeekend
    case alternatingWeek

    var title: String {
        switch self {
        case .doubleWeekend: L10n.text("workweek.double")
        case .singleWeekend: L10n.text("workweek.single")
        case .alternatingWeek: L10n.text("workweek.alternating")
        }
    }

    var saturdayLegend: String? {
        switch self {
        case .doubleWeekend: nil
        case .singleWeekend: L10n.text("calendar.single_saturday")
        case .alternatingWeek: L10n.text("calendar.alternating_saturday")
        }
    }
}

struct WorkSchedule: Equatable {
    var workStartMinutes: Int
    var workEndMinutes: Int
    var lunchStartMinutes: Int
    var lunchEndMinutes: Int
    var overtimeStartMinutes: Int
    var overtimeEndMinutes: Int
    var workweekRule: WorkweekRule
    var smallWeekAnchor: Date
}

enum EarningsCalculator {
    static func earned(hourlyRate: Double, elapsed seconds: TimeInterval) -> Double {
        guard hourlyRate > 0, seconds > 0 else { return 0 }
        return hourlyRate * seconds / 3_600
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func calendarTotals(
        hourlyRate: Double,
        overtimeRate: Double,
        overtimeDays: Set<String>,
        schedule: WorkSchedule,
        at date: Date,
        calendar: Calendar = .current
    ) -> (day: Double, month: Double) {
        let dayStart = calendar.startOfDay(for: date)
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? dayStart
        let dayTotal = dailyEarnings(
            hourlyRate: hourlyRate,
            overtimeRate: overtimeRate,
            overtimeDays: overtimeDays,
            schedule: schedule,
            on: date,
            at: date,
            calendar: calendar
        )

        var monthTotal = 0.0
        var cursor = monthStart
        while cursor <= date {
            let key = dayKey(for: cursor, calendar: calendar)
            let isOvertime = overtimeDays.contains(key)
            let regular = regularSeconds(
                on: cursor,
                until: date,
                isOvertime: isOvertime,
                schedule: schedule,
                calendar: calendar
            )
            let overtime = overtimeSeconds(
                on: cursor,
                until: date,
                isOvertime: isOvertime,
                schedule: schedule,
                calendar: calendar
            )
            monthTotal += earned(hourlyRate: hourlyRate, elapsed: regular)
            monthTotal += earned(hourlyRate: overtimeRate, elapsed: overtime)

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return (
            day: dayTotal,
            month: monthTotal
        )
    }

    static func dailyEarnings(
        hourlyRate: Double,
        overtimeRate: Double,
        overtimeDays: Set<String>,
        schedule: WorkSchedule,
        on date: Date,
        at now: Date,
        calendar: Calendar = .current
    ) -> Double {
        let isOvertime = overtimeDays.contains(dayKey(for: date, calendar: calendar))
        let regular = regularSeconds(
            on: date,
            until: now,
            isOvertime: isOvertime,
            schedule: schedule,
            calendar: calendar
        )
        let overtime = overtimeSeconds(
            on: date,
            until: now,
            isOvertime: isOvertime,
            schedule: schedule,
            calendar: calendar
        )
        return earned(hourlyRate: hourlyRate, elapsed: regular)
            + earned(hourlyRate: overtimeRate, elapsed: overtime)
    }

    static func normalizedSaturday(for date: Date, calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: date) ?? date
        return calendar.startOfDay(for: saturday)
    }

    static func isSmallSaturday(
        _ date: Date,
        anchor: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard calendar.component(.weekday, from: date) == 7 else { return false }

        let candidate = calendar.startOfDay(for: date)
        let anchorDay = normalizedSaturday(for: anchor, calendar: calendar)
        let daysFromAnchor = calendar.dateComponents(
            [.day],
            from: anchorDay,
            to: candidate
        ).day ?? 0
        return (daysFromAnchor / 7).isMultiple(of: 2)
    }

    static func isRegularWorkday(
        _ date: Date,
        schedule: WorkSchedule,
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard !(2...6).contains(weekday) else { return true }

        switch schedule.workweekRule {
        case .doubleWeekend:
            return false
        case .singleWeekend:
            return weekday == 7
        case .alternatingWeek:
            return isSmallSaturday(
                date,
                anchor: schedule.smallWeekAnchor,
                calendar: calendar
            )
        }
    }

    private static func regularSeconds(
        on date: Date,
        until now: Date,
        isOvertime: Bool,
        schedule: WorkSchedule,
        calendar: Calendar
    ) -> TimeInterval {
        guard isRegularWorkday(date, schedule: schedule, calendar: calendar) else {
            return 0
        }

        let endMinutes = isOvertime
            ? min(schedule.workEndMinutes, schedule.overtimeStartMinutes)
            : schedule.workEndMinutes
        return elapsedSeconds(
            on: date,
            until: now,
            startMinutes: schedule.workStartMinutes,
            endMinutes: endMinutes,
            excludedStartMinutes: schedule.lunchStartMinutes,
            excludedEndMinutes: schedule.lunchEndMinutes,
            calendar: calendar
        )
    }

    private static func overtimeSeconds(
        on date: Date,
        until now: Date,
        isOvertime: Bool,
        schedule: WorkSchedule,
        calendar: Calendar
    ) -> TimeInterval {
        guard isOvertime else { return 0 }
        return elapsedSeconds(
            on: date,
            until: now,
            startMinutes: schedule.overtimeStartMinutes,
            endMinutes: schedule.overtimeEndMinutes,
            calendar: calendar
        )
    }

    private static func elapsedSeconds(
        on date: Date,
        until now: Date,
        startMinutes: Int,
        endMinutes: Int,
        excludedStartMinutes: Int? = nil,
        excludedEndMinutes: Int? = nil,
        calendar: Calendar
    ) -> TimeInterval {

        let dayStart = calendar.startOfDay(for: date)
        guard dayStart <= now else { return 0 }

        guard
            let start = time(on: date, minutes: startMinutes, calendar: calendar),
            let end = time(on: date, minutes: endMinutes, calendar: calendar),
            end > start
        else { return 0 }

        let effectiveEnd = dayStart < calendar.startOfDay(for: now) ? end : min(now, end)
        let grossSeconds = max(0, effectiveEnd.timeIntervalSince(start))
        guard grossSeconds > 0 else { return 0 }

        guard
            let excludedStartMinutes,
            let excludedEndMinutes,
            let lunchStart = time(
                on: date,
                minutes: excludedStartMinutes,
                calendar: calendar
            ),
            let lunchEnd = time(
                on: date,
                minutes: excludedEndMinutes,
                calendar: calendar
            ),
            lunchEnd > lunchStart
        else { return grossSeconds }

        let overlapStart = max(start, lunchStart)
        let overlapEnd = min(effectiveEnd, lunchEnd)
        let lunchSeconds = max(0, overlapEnd.timeIntervalSince(overlapStart))
        return max(0, grossSeconds - lunchSeconds)
    }

    private static func time(
        on date: Date,
        minutes: Int,
        calendar: Calendar
    ) -> Date? {
        let clampedMinutes = min(max(minutes, 0), 23 * 60 + 59)
        return calendar.date(
            bySettingHour: clampedMinutes / 60,
            minute: clampedMinutes % 60,
            second: 0,
            of: date
        )
    }
}
