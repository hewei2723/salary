import AppKit
import Foundation

@MainActor
final class EarningsStore: NSObject, ObservableObject {
    @Published private(set) var hourlyRate: Double
    @Published private(set) var overtimeRate: Double
    @Published private(set) var intervalSeconds: Int
    @Published private(set) var dayTotal: Double
    @Published private(set) var monthTotal: Double
    @Published private(set) var overtimeDays: Set<String>
    @Published private(set) var workStartMinutes: Int
    @Published private(set) var workEndMinutes: Int
    @Published private(set) var lunchStartMinutes: Int
    @Published private(set) var lunchEndMinutes: Int
    @Published private(set) var overtimeStartMinutes: Int
    @Published private(set) var overtimeEndMinutes: Int
    @Published private(set) var workweekRule: WorkweekRule
    @Published private(set) var smallWeekAnchor: Date

    private enum Key {
        static let hourlyRate = "salaryCharger.hourlyRate"
        static let overtimeRate = "salaryCharger.overtimeRate"
        static let intervalSeconds = "salaryCharger.intervalSeconds"
        static let overtimeDays = "salaryCharger.overtimeDays"
        static let workStartMinutes = "salaryCharger.workStartMinutes"
        static let workEndMinutes = "salaryCharger.workEndMinutes"
        static let lunchStartMinutes = "salaryCharger.lunchStartMinutes"
        static let lunchEndMinutes = "salaryCharger.lunchEndMinutes"
        static let overtimeStartMinutes = "salaryCharger.overtimeStartMinutes"
        static let overtimeEndMinutes = "salaryCharger.overtimeEndMinutes"
        static let workweekRule = "salaryCharger.workweekRule"
        static let smallWeekAnchor = "salaryCharger.smallWeekAnchor"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var timer: Timer?

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.defaults = defaults
        self.calendar = calendar

        let storedRate = defaults.double(forKey: Key.hourlyRate)
        let resolvedRate = storedRate > 0 ? storedRate : 100
        hourlyRate = resolvedRate

        let storedOvertimeRate = defaults.double(forKey: Key.overtimeRate)
        let resolvedOvertimeRate = storedOvertimeRate > 0
            ? storedOvertimeRate
            : resolvedRate * 1.5
        overtimeRate = resolvedOvertimeRate

        let storedInterval = defaults.integer(forKey: Key.intervalSeconds)
        intervalSeconds = storedInterval > 0 ? min(storedInterval, 3_600) : 5
        let resolvedOvertimeDays = Set(defaults.stringArray(forKey: Key.overtimeDays) ?? [])
        overtimeDays = resolvedOvertimeDays

        func storedMinutes(_ key: String, fallback: Int) -> Int {
            guard defaults.object(forKey: key) != nil else { return fallback }
            return min(max(defaults.integer(forKey: key), 0), 23 * 60 + 59)
        }

        let resolvedWorkStart = storedMinutes(Key.workStartMinutes, fallback: 9 * 60 + 30)
        let resolvedWorkEnd = storedMinutes(Key.workEndMinutes, fallback: 18 * 60 + 30)
        let resolvedLunchStart = storedMinutes(Key.lunchStartMinutes, fallback: 12 * 60)
        let resolvedLunchEnd = storedMinutes(Key.lunchEndMinutes, fallback: 13 * 60)
        let resolvedOvertimeStart = storedMinutes(
            Key.overtimeStartMinutes,
            fallback: 18 * 60 + 30
        )
        let resolvedOvertimeEnd = storedMinutes(
            Key.overtimeEndMinutes,
            fallback: 20 * 60 + 30
        )
        workStartMinutes = resolvedWorkStart
        workEndMinutes = resolvedWorkEnd
        lunchStartMinutes = resolvedLunchStart
        lunchEndMinutes = resolvedLunchEnd
        overtimeStartMinutes = resolvedOvertimeStart
        overtimeEndMinutes = resolvedOvertimeEnd

        let storedWorkweekRule = defaults.string(forKey: Key.workweekRule)
        let resolvedWorkweekRule = storedWorkweekRule.flatMap(WorkweekRule.init(rawValue:))
            ?? .alternatingWeek
        workweekRule = resolvedWorkweekRule

        let defaultAnchor = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: 15
            )
        ) ?? now
        let storedAnchor = defaults.object(forKey: Key.smallWeekAnchor) as? Date ?? defaultAnchor
        let resolvedAnchor = EarningsCalculator.normalizedSaturday(
            for: storedAnchor,
            calendar: calendar
        )
        smallWeekAnchor = resolvedAnchor

        let resolvedSchedule = WorkSchedule(
            workStartMinutes: resolvedWorkStart,
            workEndMinutes: resolvedWorkEnd,
            lunchStartMinutes: resolvedLunchStart,
            lunchEndMinutes: resolvedLunchEnd,
            overtimeStartMinutes: resolvedOvertimeStart,
            overtimeEndMinutes: resolvedOvertimeEnd,
            workweekRule: resolvedWorkweekRule,
            smallWeekAnchor: resolvedAnchor
        )
        let totals = EarningsCalculator.calendarTotals(
            hourlyRate: resolvedRate,
            overtimeRate: resolvedOvertimeRate,
            overtimeDays: resolvedOvertimeDays,
            schedule: resolvedSchedule,
            at: now,
            calendar: calendar
        )
        dayTotal = totals.day
        monthTotal = totals.month

        super.init()
        persist()
        scheduleTimer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    var currencySymbol: String {
        Locale.current.currencySymbol ?? "¥"
    }

    var schedule: WorkSchedule {
        WorkSchedule(
            workStartMinutes: workStartMinutes,
            workEndMinutes: workEndMinutes,
            lunchStartMinutes: lunchStartMinutes,
            lunchEndMinutes: lunchEndMinutes,
            overtimeStartMinutes: overtimeStartMinutes,
            overtimeEndMinutes: overtimeEndMinutes,
            workweekRule: workweekRule,
            smallWeekAnchor: smallWeekAnchor
        )
    }

    var workTimeText: String {
        "\(formatMinutes(workStartMinutes)) - \(formatMinutes(workEndMinutes))"
    }

    var lunchTimeText: String {
        "\(formatMinutes(lunchStartMinutes)) - \(formatMinutes(lunchEndMinutes))"
    }

    var overtimeTimeText: String {
        "\(formatMinutes(overtimeStartMinutes)) - \(formatMinutes(overtimeEndMinutes))"
    }

    var intervalEarnings: Double {
        let now = Date()
        let current = totals(at: now)
        let next = totals(at: now.addingTimeInterval(TimeInterval(intervalSeconds)))
        return max(0, next.month - current.month)
    }

    var compactDayText: String {
        format(dayTotal, grouping: true)
    }

    var compactTotalText: String {
        format(monthTotal, grouping: true)
    }

    var compactIntervalText: String {
        format(intervalEarnings, grouping: false)
    }

    var workStartTime: Date { dateForMinutes(workStartMinutes) }
    var workEndTime: Date { dateForMinutes(workEndMinutes) }
    var lunchStartTime: Date { dateForMinutes(lunchStartMinutes) }
    var lunchEndTime: Date { dateForMinutes(lunchEndMinutes) }
    var overtimeStartTime: Date { dateForMinutes(overtimeStartMinutes) }
    var overtimeEndTime: Date { dateForMinutes(overtimeEndMinutes) }

    func updateHourlyRate(_ value: Double) {
        hourlyRate = min(max(value, 0), 1_000_000)
        refresh(at: Date())
    }

    func updateOvertimeRate(_ value: Double) {
        overtimeRate = min(max(value, 0), 1_000_000)
        refresh(at: Date())
    }

    func updateInterval(_ value: Int) {
        intervalSeconds = min(max(value, 1), 3_600)
        persist()
        scheduleTimer()
    }

    func updateWorkStart(_ value: Date) {
        workStartMinutes = minutes(from: value)
        refresh(at: Date())
    }

    func updateWorkEnd(_ value: Date) {
        workEndMinutes = minutes(from: value)
        refresh(at: Date())
    }

    func updateLunchStart(_ value: Date) {
        lunchStartMinutes = minutes(from: value)
        refresh(at: Date())
    }

    func updateLunchEnd(_ value: Date) {
        lunchEndMinutes = minutes(from: value)
        refresh(at: Date())
    }

    func updateOvertimeStart(_ value: Date) {
        overtimeStartMinutes = minutes(from: value)
        refresh(at: Date())
    }

    func updateOvertimeEnd(_ value: Date) {
        overtimeEndMinutes = minutes(from: value)
        refresh(at: Date())
    }

    func updateWorkweekRule(_ value: WorkweekRule) {
        workweekRule = value
        refresh(at: Date())
    }

    func updateSmallWeekAnchor(_ value: Date) {
        smallWeekAnchor = EarningsCalculator.normalizedSaturday(for: value, calendar: calendar)
        refresh(at: Date())
    }

    func toggleOvertime(on date: Date) {
        let key = EarningsCalculator.dayKey(for: date, calendar: calendar)
        if overtimeDays.contains(key) {
            overtimeDays.remove(key)
        } else {
            overtimeDays.insert(key)
        }
        refresh(at: Date())
    }

    func isOvertime(_ date: Date) -> Bool {
        overtimeDays.contains(EarningsCalculator.dayKey(for: date, calendar: calendar))
    }

    func isWorkingSaturday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 7
            && EarningsCalculator.isRegularWorkday(
                date,
                schedule: schedule,
                calendar: calendar
            )
    }

    func overtimeCount(inMonth date: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        let monthPrefix = EarningsCalculator.monthKey(for: interval.start, calendar: calendar)
        return overtimeDays.filter { $0.hasPrefix(monthPrefix) }.count
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(intervalSeconds),
            target: self,
            selector: #selector(timerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = min(TimeInterval(intervalSeconds) * 0.05, 1)
    }

    @objc private func timerFired(_ timer: Timer) {
        refresh(at: Date())
    }

    private func totals(at date: Date) -> (day: Double, month: Double) {
        EarningsCalculator.calendarTotals(
            hourlyRate: hourlyRate,
            overtimeRate: overtimeRate,
            overtimeDays: overtimeDays,
            schedule: schedule,
            at: date,
            calendar: calendar
        )
    }

    private func refresh(at now: Date) {
        let totals = totals(at: now)
        dayTotal = totals.day
        monthTotal = totals.month
        persist()
    }

    private func persist() {
        defaults.set(hourlyRate, forKey: Key.hourlyRate)
        defaults.set(overtimeRate, forKey: Key.overtimeRate)
        defaults.set(intervalSeconds, forKey: Key.intervalSeconds)
        defaults.set(Array(overtimeDays).sorted(), forKey: Key.overtimeDays)
        defaults.set(workStartMinutes, forKey: Key.workStartMinutes)
        defaults.set(workEndMinutes, forKey: Key.workEndMinutes)
        defaults.set(lunchStartMinutes, forKey: Key.lunchStartMinutes)
        defaults.set(lunchEndMinutes, forKey: Key.lunchEndMinutes)
        defaults.set(overtimeStartMinutes, forKey: Key.overtimeStartMinutes)
        defaults.set(overtimeEndMinutes, forKey: Key.overtimeEndMinutes)
        defaults.set(workweekRule.rawValue, forKey: Key.workweekRule)
        defaults.set(smallWeekAnchor, forKey: Key.smallWeekAnchor)
    }

    private func minutes(from date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func dateForMinutes(_ minutes: Int) -> Date {
        calendar.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func formatMinutes(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func format(_ value: Double, grouping: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    @objc private func applicationWillTerminate() {
        refresh(at: Date())
        timer?.invalidate()
    }
}
