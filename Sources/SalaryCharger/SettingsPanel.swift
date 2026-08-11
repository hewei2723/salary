import AppKit
import SwiftUI

struct SettingsPanel: View {
    @ObservedObject var store: EarningsStore
    @State private var showsSettings = false
    @State private var showsLaunchAtLoginAlert = false
    @State private var launchAtLoginMessage = ""

    var body: some View {
        Group {
            if showsSettings {
                settingsPage
            } else {
                dashboard
            }
        }
        .frame(width: 296, height: showsSettings ? 380 : 315, alignment: .top)
        .background(VisualEffectView().ignoresSafeArea())
        .alert(L10n.text("launch.alert.title"), isPresented: $showsLaunchAtLoginAlert) {
            Button(L10n.text("action.ok"), role: .cancel) {}
        } message: {
            Text(launchAtLoginMessage)
        }
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            dashboardHeader

            HStack(spacing: 14) {
                metric(title: L10n.text("dashboard.today"), value: store.compactDayText)

                Divider()
                .frame(height: 36)

                metric(title: L10n.text("dashboard.month"), value: store.compactTotalText)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            MonthCalendarPanel(store: store)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Spacer(minLength: 0)
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 10) {
            Text(L10n.text("app.name"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                store.refreshLaunchAtLoginStatus()
                showsSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help(L10n.text("action.settings"))

            quitButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var settingsPage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    showsSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(L10n.text("action.back"))

                Text(L10n.text("settings.title"))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
                quitButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 0) {
                sectionTitle(L10n.text("settings.section.pay"))
                settingRow(title: L10n.text("settings.hourly_rate"), icon: "banknote", tint: .green) {
                    rateField(
                        value: Binding(
                            get: { store.hourlyRate },
                            set: { store.updateHourlyRate($0) }
                        )
                    )
                }
                rowDivider
                settingRow(title: L10n.text("settings.overtime_rate"), icon: "moon.stars", tint: .orange) {
                    rateField(
                        value: Binding(
                            get: { store.overtimeRate },
                            set: { store.updateOvertimeRate($0) }
                        )
                    )
                }

                sectionTitle(L10n.text("settings.section.schedule"))
                settingRow(title: L10n.text("settings.work_hours"), icon: "briefcase", tint: .blue) {
                    timeRange(
                        start: Binding(
                            get: { store.workStartTime },
                            set: { store.updateWorkStart($0) }
                        ),
                        end: Binding(
                            get: { store.workEndTime },
                            set: { store.updateWorkEnd($0) }
                        )
                    )
                }
                rowDivider
                settingRow(title: L10n.text("settings.lunch_hours"), icon: "cup.and.saucer", tint: .mint) {
                    timeRange(
                        start: Binding(
                            get: { store.lunchStartTime },
                            set: { store.updateLunchStart($0) }
                        ),
                        end: Binding(
                            get: { store.lunchEndTime },
                            set: { store.updateLunchEnd($0) }
                        )
                    )
                }
                rowDivider
                settingRow(title: L10n.text("settings.overtime_hours"), icon: "moon.zzz", tint: .red) {
                    timeRange(
                        start: Binding(
                            get: { store.overtimeStartTime },
                            set: { store.updateOvertimeStart($0) }
                        ),
                        end: Binding(
                            get: { store.overtimeEndTime },
                            set: { store.updateOvertimeEnd($0) }
                        )
                    )
                }

                sectionTitle(L10n.text("settings.section.rules"))
                settingRow(title: L10n.text("settings.workweek"), icon: "calendar", tint: .purple) {
                    Picker(
                        "",
                        selection: Binding(
                            get: { store.workweekRule },
                            set: { store.updateWorkweekRule($0) }
                        )
                    ) {
                        ForEach(WorkweekRule.allCases, id: \.self) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 174)
                }
                rowDivider
                if store.workweekRule == .alternatingWeek {
                    settingRow(
                        title: L10n.text("settings.alternating_saturday"),
                        icon: "calendar.badge.clock",
                        tint: .cyan
                    ) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { store.smallWeekAnchor },
                                set: { store.updateSmallWeekAnchor($0) }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    rowDivider
                }
                settingRow(title: L10n.text("settings.refresh_interval"), icon: "timer", tint: .secondary) {
                    Stepper(
                        value: Binding(
                            get: { store.intervalSeconds },
                            set: { store.updateInterval($0) }
                        ),
                        in: 1...3_600,
                        step: 1
                    ) {
                        Text(L10n.format("settings.interval_seconds", store.intervalSeconds))
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                    }
                }
                rowDivider
                settingRow(title: L10n.text("settings.launch_at_login"), icon: "power.circle", tint: .green) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.launchesAtLogin },
                            set: { enabled in
                                if let message = store.updateLaunchAtLogin(enabled) {
                                    launchAtLoginMessage = message
                                    showsLaunchAtLoginAlert = true
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .controlSize(.small)
        }
    }

    private var quitButton: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "power")
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .help(L10n.text("action.quit"))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(store.currencySymbol)\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 7)
            .padding(.bottom, 2)
    }

    private func rateField(value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(store.currencySymbol)
                .foregroundStyle(.secondary)
            TextField(
                "",
                value: value,
                format: .number.precision(.fractionLength(0...2))
            )
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: 82)
        }
    }

    private func settingRow<Control: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 8)
            control()
        }
        .frame(height: 28)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 28)
    }

    private func timeRange(start: Binding<Date>, end: Binding<Date>) -> some View {
        HStack(spacing: 4) {
            compactTimePicker(start)

            Text("-")
                .foregroundStyle(.tertiary)

            compactTimePicker(end)
        }
    }

    private func compactTimePicker(_ value: Binding<Date>) -> some View {
        DatePicker("", selection: value, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .frame(width: 70)
    }
}
