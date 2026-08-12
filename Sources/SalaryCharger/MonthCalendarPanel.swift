import SwiftUI

struct MonthCalendarPanel: View {
    @ObservedObject var store: EarningsStore
    @Binding var selectedDate: Date?
    @State private var displayedMonth = Date()
    @Environment(\.displayScale) private var displayScale

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = L10n.locale
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth
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
        let populatedDays = emptyDays + dates
        let trailingEmptyDays = max(0, 42 - populatedDays.count)
        return populatedDays + Array<Date?>(repeating: nil, count: trailingEmptyDays)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                monthNavigationButton(
                    systemImage: "chevron.left",
                    helpKey: "calendar.previous_month",
                    offset: -1
                )

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(minWidth: 72)

                monthNavigationButton(
                    systemImage: "chevron.right",
                    helpKey: "calendar.next_month",
                    offset: 1
                )

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
                spacing: 2
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
                            .frame(width: 32, height: 22)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ViewThatFits(in: .horizontal) {
                legendRow(includingWorkTime: true)
                legendRow(includingWorkTime: false)
            }
        }
    }

    private var legendFontSize: CGFloat {
        displayScale <= 1.5 ? 10 : 9
    }

    private func monthNavigationButton(
        systemImage: String,
        helpKey: String,
        offset: Int
    ) -> some View {
        Button {
            guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
                return
            }
            displayedMonth = month
            selectedDate = nil
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(L10n.text(helpKey))
        .accessibilityLabel(L10n.text(helpKey))
    }

    private func legendRow(includingWorkTime: Bool) -> some View {
        HStack(spacing: 10) {
            if let saturdayLegend = store.workweekRule.saturdayLegend {
                legendLabel(saturdayLegend, color: .cyan)
            }
            legendLabel(L10n.text("calendar.rest_day"), color: .green)
            legendLabel(L10n.text("calendar.overtime_day"), color: .orange)

            if includingWorkTime {
                Spacer(minLength: 0)
                Text(store.workTimeText)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .font(.system(size: legendFontSize, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 14)
    }

    private func legendLabel(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(color, color)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func dayButton(_ date: Date) -> some View {
        let isOvertime = store.isOvertime(date)
        let isRestDay = store.isRestDay(date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isWorkingSaturday = store.isWorkingSaturday(date)

        return Button {
            selectedDate = date
        } label: {
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(dayBackground(isOvertime: isOvertime, isRestDay: isRestDay))
                    .overlay {
                        if isSelected {
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        } else if isToday {
                            Circle()
                                .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
                        }
                    }

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 10, weight: isToday || isOvertime ? .semibold : .regular))
                    .foregroundStyle(
                        isOvertime ? Color.orange : isRestDay ? Color.green : Color.primary
                    )
                    .frame(maxHeight: .infinity)

                if isWorkingSaturday && !isOvertime {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 3, height: 3)
                        .padding(.bottom, 2)
                }
            }
            .frame(width: 21, height: 21)
            .frame(width: 32, height: 22)
            .contentShape(Rectangle())
        }
        .frame(width: 32, height: 22)
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                selectedDate = date
                store.toggleOvertime(on: date)
            } label: {
                Label(
                    isOvertime
                        ? L10n.text("calendar.remove_overtime")
                        : L10n.text("calendar.mark_overtime"),
                    systemImage: isOvertime ? "clock.badge.xmark" : "clock.badge.checkmark"
                )
            }
        }
        .help(L10n.text("calendar.day_help"))
    }

    private func dayBackground(isOvertime: Bool, isRestDay: Bool) -> Color {
        if isOvertime {
            return Color.orange.opacity(0.18)
        }
        if isRestDay {
            return Color.green.opacity(0.14)
        }
        return Color.clear
    }
}
