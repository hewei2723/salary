import SwiftUI

struct MonthCalendarPanel: View {
    @ObservedObject var store: EarningsStore

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = L10n.locale
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    }

    private var title: String {
        monthStart.formatted(
            Date.FormatStyle()
                .year(.defaultDigits)
                .month(.wide)
                .locale(L10n.locale)
        )
    }

    private var weekdaySymbols: [String] {
        [
            L10n.text("weekday.mon"),
            L10n.text("weekday.tue"),
            L10n.text("weekday.wed"),
            L10n.text("weekday.thu"),
            L10n.text("weekday.fri"),
            L10n.text("weekday.sat"),
            L10n.text("weekday.sun")
        ]
    }

    private var days: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let emptyDays = Array<Date?>(repeating: nil, count: leadingEmptyDays)
        let dates = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }.map(Optional.some)
        return emptyDays + dates
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Label(
                    L10n.format(
                        "calendar.overtime_count",
                        store.overtimeCount(inMonth: monthStart)
                    ),
                    systemImage: "clock.badge.checkmark"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(32), spacing: 5), count: 7),
                alignment: .center,
                spacing: 3
            ) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 12)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear
                            .frame(width: 32, height: 25)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 14) {
                if let saturdayLegend = store.workweekRule.saturdayLegend {
                    Label(saturdayLegend, systemImage: "circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.cyan, .cyan)
                }
                Label(L10n.text("calendar.overtime_day"), systemImage: "circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.orange, .orange)
                Spacer()
                Text(store.workTimeText)
                    .monospacedDigit()
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let isOvertime = store.isOvertime(date)
        let isToday = calendar.isDateInToday(date)
        let isWorkingSaturday = store.isWorkingSaturday(date)

        return Button {
            store.toggleOvertime(on: date)
        } label: {
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(isOvertime ? Color.orange.opacity(0.18) : Color.clear)
                    .overlay {
                        if isToday {
                            Circle()
                                .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
                        }
                    }

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 10, weight: isToday || isOvertime ? .semibold : .regular))
                    .foregroundStyle(isOvertime ? Color.orange : Color.primary)
                    .frame(maxHeight: .infinity)

                if isWorkingSaturday && !isOvertime {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 3, height: 3)
                        .padding(.bottom, 2)
                }
            }
            .frame(width: 23, height: 23)
            .frame(width: 32, height: 25)
            .contentShape(Rectangle())
        }
        .frame(width: 32, height: 25)
        .buttonStyle(.plain)
        .help(
            isOvertime
                ? L10n.text("calendar.remove_overtime")
                : L10n.text("calendar.mark_overtime")
        )
    }
}
