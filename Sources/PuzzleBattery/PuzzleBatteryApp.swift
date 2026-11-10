import AppKit
import BatteryCore
import SwiftUI

@main
struct PuzzleBatteryApp: App {
    @StateObject private var monitor = BatteryMonitor()
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some Scene {
        Window("PuzzleBattery", id: "main") {
            DashboardView().environmentObject(monitor)
                .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 460, height: 712)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Battery") {
                Button("Refresh Now") { monitor.refresh() }.keyboardShortcut("r")
                Button("Save Reading") { monitor.saveReading() }.keyboardShortcut("s")
                Button("Copy Battery Report") { monitor.copyReport() }.keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarView().environmentObject(monitor)
        } label: {
            Label(monitor.snapshot.percentage.map { "\(Int($0.rounded()))%" } ?? "—", systemImage: monitor.snapshot.isCharging ? "battery.100percent.bolt" : "battery.100percent")
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView().environmentObject(monitor)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var monitor: BatteryMonitor
    @AppStorage("showMenuBar") private var showMenuBar = true
    var body: some View {
        Form {
            Section("Monitoring") {
                Toggle("Show battery in the menu bar", isOn: $showMenuBar)
                Picker("Refresh readings", selection: $monitor.refreshInterval) {
                    Text("Every 10 seconds").tag(10.0)
                    Text("Every 30 seconds").tag(30.0)
                    Text("Every minute").tag(60.0)
                }
            }
            Section("History") {
                Toggle("Save a reading each day while running", isOn: $monitor.automaticHistory)
                Text("Readings are stored in Application Support/PuzzleBattery on this Mac. PuzzleBattery does not send data to a server.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).padding().frame(width: 440, height: 280)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var monitor: BatteryMonitor
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill").foregroundStyle(Palette.green)
                Text("PuzzleBattery").fontWeight(.semibold)
                Spacer()
                Text(monitor.snapshot.status).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(monitor.snapshot.percentage.map { "\(Int($0.rounded()))%" } ?? "—").font(.system(size: 34, weight: .medium, design: .rounded))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Battery health").font(.caption).foregroundStyle(.secondary)
                    Text(monitor.snapshot.health.map { String(format: "%.1f%%", $0) } ?? "Unavailable").fontWeight(.medium)
                }
            }
            Divider()
            Button("Open PuzzleBattery") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
            Button("Refresh Now") { monitor.refresh() }
            Button("Quit PuzzleBattery") { NSApp.terminate(nil) }
        }.padding(18).frame(width: 300)
    }
}
