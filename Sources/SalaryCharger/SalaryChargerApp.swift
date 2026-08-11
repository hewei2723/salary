import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct SalaryChargerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = EarningsStore()

    var body: some Scene {
        MenuBarExtra {
            SettingsPanel(store: store)
        } label: {
            Text(L10n.format(
                "menu.summary",
                store.currencySymbol,
                store.compactDayText,
                store.currencySymbol,
                store.compactTotalText
            ))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 216, alignment: .trailing)
        }
        .menuBarExtraStyle(.window)
    }
}
