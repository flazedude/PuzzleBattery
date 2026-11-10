import AppKit
import BatteryCore
import Charts
import SwiftUI

// Disambiguate the property wrapper from the State macro in newer SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let green = Color(red: 0.13, green: 0.71, blue: 0.30)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let border = Color.primary.opacity(0.08)
}

private enum DashboardTab: String, CaseIterable {
    case mac = "This Mac", history = "History", insights = "Insights"
    var symbol: String {
        switch self { case .mac: "waveform.path.ecg"; case .history: "clock.arrow.circlepath"; case .insights: "chart.xyaxis.line" }
    }
}
private enum Detail: String, Identifiable { case mac, battery; var id: String { rawValue } }

struct DashboardView: View {
    @EnvironmentObject private var monitor: BatteryMonitor
    @ViewState<DashboardTab> private var tab = .mac
    @ViewState<Detail?> private var detail = nil
    @ViewState<Bool> private var confirmClear = false
    private var s: BatterySnapshot { monitor.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(DashboardTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.symbol).font(.system(size: 22, weight: .regular)).frame(height: 25)
                            Text(item.rawValue).font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(tab == item ? Color.accentColor : Color.secondary)
                        .frame(width: 100, height: 66)
                        .background(tab == item ? Palette.card : .clear, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tab == item ? Palette.border : .clear))
                    }.buttonStyle(.plain).accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }.frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 14).fixedSize(horizontal: false, vertical: true)
            Divider()
            Group {
                switch tab {
                case .mac: ScrollView { macView }
                case .history: historyView
                case .insights: ScrollView { insightsView }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(width: 460, height: 710)
        .background(Palette.canvas)
        .sheet(item: $detail) { detail in DetailView(detail: detail.rawValue).environmentObject(monitor) }
        .alert("PuzzleBattery", isPresented: Binding(get: { monitor.message != nil }, set: { if !$0 { monitor.message = nil } })) {
            Button("OK") { monitor.message = nil }
        } message: { Text(monitor.message ?? "") }
        .confirmationDialog("Clear saved history for this Mac?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { monitor.deleteHistory() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the saved readings for this Mac. Export a CSV first if you want to keep a copy.") }
    }

    private var macView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 17) {
                HStack(spacing: 17) {
                    MacIllustration().frame(width: 66, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monitor.identity.name).font(.system(size: 20, weight: .semibold))
                        Text("\(monitor.identity.chip) · \(monitor.identity.memory)").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                MetricRow(title: "Device identifier", value: monitor.identity.model)
                HStack(spacing: 12) {
                    Button("Mac Info…") { detail = .mac }.frame(maxWidth: .infinity)
                    Button("Battery Info…") { detail = .battery }.frame(maxWidth: .infinity)
                }.buttonStyle(SoftButtonStyle())
            }.padding(24).background(Palette.card.opacity(0.65))
            Divider()
            if s.isPresent {
                VStack(spacing: 17) {
                    CapacityBar(title: "Battery charge", value: capacity(s.currentCapacity), percentage: s.percentage, color: (s.percentage ?? 100) <= 20 ? .orange : Palette.green)
                    CapacityBar(title: "Battery health", value: s.needsService ? "Service recommended" : "", percentage: s.health, color: s.needsService ? .orange : Palette.green)
                    VStack(spacing: 12) {
                        MetricRow(title: "Full charge capacity", value: capacity(s.fullCapacity))
                        MetricRow(title: "Design capacity", value: capacity(s.designCapacity))
                        MetricRow(title: "Manufacture date", value: s.manufactureDate.map { $0.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)) } ?? "Unavailable")
                        MetricRow(title: "Charge cycles", value: s.cycles.map { $0.formatted() } ?? "Unavailable")
                        MetricRow(title: "Battery temperature", value: s.temperature.map { String(format: "%.1f °C", $0) } ?? "Unavailable")
                        MetricRow(title: s.isCharging ? "Charging with" : "Power draw", value: s.watts.map { String(format: "%.1f W", $0) } ?? "Unavailable")
                        MetricRow(title: "Low Power Mode", value: s.lowPowerMode ? "Enabled" : "Disabled")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: s.externalConnected ? "powerplug.fill" : "battery.75percent").foregroundStyle(s.isCharging ? Palette.green : .secondary)
                        Text(s.status)
                        if let time = s.timeRemaining { Text("· \(duration(time)) \(s.isCharging ? "until full" : "remaining")") }
                        Spacer(minLength: 0)
                    }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 1)
                }.padding(.horizontal, 28).padding(.top, 21)
            } else {
                ContentUnavailableView("No internal battery", systemImage: "desktopcomputer", description: Text("Battery readings are available on a Mac with a built-in battery. Try refreshing if a battery was expected."))
            }
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A little history. A clearer picture.").font(.system(size: 18, weight: .semibold))
                    Text("Battery health over time, saved on this Mac.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if monitor.deviceHistory.isEmpty {
                ContentUnavailableView("Your history starts here", systemImage: "clock.arrow.circlepath", description: Text("Save your first reading to track capacity and charge cycles over time."))
                    .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CAPACITY RETAINED").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(monitor.deviceHistory.count) \(monitor.deviceHistory.count == 1 ? "reading" : "readings")").font(.caption).foregroundStyle(.secondary)
                    }
                    Chart(monitor.deviceHistory) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Health", entry.health)).foregroundStyle(Palette.green).interpolationMethod(.linear)
                        PointMark(x: .value("Date", entry.date), y: .value("Health", entry.health)).foregroundStyle(Palette.green).symbolSize(32)
                    }
                    .chartYScale(domain: 0...max(105, (monitor.deviceHistory.map(\.health).max() ?? 100) + 5))
                    .chartXScale(domain: chartDateRange)
                    .chartYAxis { AxisMarks(values: [0, 50, 100]) { value in AxisGridLine(); AxisValueLabel { if let n = value.as(Int.self) { Text("\(n)%") } } } }
                    .chartXAxis { AxisMarks(values: historyAxisDates) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .frame(height: 150)
                    Text(monitor.deviceHistory.count == 1 ? "One reading saved. Save more readings to see a trend." : "Each point is a saved reading of full charge capacity ÷ design capacity.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(16).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Text("SAVED READINGS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Button("Export CSV…") { monitor.exportHistory() }.buttonStyle(.link).font(.system(size: 11))
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(monitor.deviceHistory.reversed()) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12, weight: .medium))
                                    Text("\(entry.fullCapacity.formatted()) mAh · \(entry.cycles.map { "\($0) cycles" } ?? "Cycles unavailable")").font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f%%", entry.health)).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Palette.green)
                            }.padding(.vertical, 11)
                            Divider()
                        }
                    }
                }
                Button("Clear history…", role: .destructive) { confirmClear = true }.buttonStyle(.link).font(.system(size: 11))
            }
        }.padding(24)
    }

    private var insightsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Get to know your battery.").font(.system(size: 18, weight: .semibold))
                Text("A closer look at this Mac, right now.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                InsightTile(symbol: "heart.fill", title: "Health", value: s.health.map { String(format: "%.1f%%", $0) } ?? "—")
                InsightTile(symbol: "arrow.triangle.2.circlepath", title: "Cycles", value: s.cycles.map { $0.formatted() } ?? "—")
                InsightTile(symbol: "thermometer.medium", title: "Temperature", value: s.temperature.map { String(format: "%.1f°", $0) } ?? "—")
            }
            VStack(alignment: .leading, spacing: 12) {
                Label(s.health == nil ? "Health unavailable" : s.needsService ? "Your battery may need service" : "Your battery is holding up", systemImage: s.health == nil ? "info.circle" : s.needsService ? "exclamationmark.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(s.needsService ? .orange : Palette.green)
                Text(healthDescription).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 13) {
                MetricRow(title: "Power source", value: s.externalConnected ? "Power adapter" : s.isPresent ? "Battery" : "Unavailable")
                MetricRow(title: "Adapter rating", value: s.adapterWatts.map { "\($0) W" } ?? (s.externalConnected ? "Unavailable" : "Not connected"))
                MetricRow(title: "Battery voltage", value: s.voltage.map { String(format: "%.2f V", $0) } ?? "Unavailable")
                MetricRow(title: "Battery current", value: s.amperage.map { String(format: "%.2f A", $0) } ?? "Unavailable")
                MetricRow(title: "Battery condition", value: s.condition ?? (s.isPresent ? "Not reported" : "Unavailable"))
            }.padding(18).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "leaf").foregroundStyle(Palette.green)
                Text("Keep it cool. Enable Optimized Battery Charging in System Settings to help reduce battery aging.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
            }.padding(.horizontal, 2)
            Button("Copy Battery Report") { monitor.copyReport() }.buttonStyle(SoftButtonStyle())
            Spacer(minLength: 0)
        }.padding(24)
    }

    private var healthDescription: String {
        guard let health = s.health else { return "This Mac is not reporting the capacities needed to calculate battery health." }
        return "Your battery can hold \(String(format: "%.1f", health))% of its original design capacity. " + (s.needsService ? "Consider checking Battery Health in System Settings for Apple's service guidance." : "Capacity changes with age, usage, and temperature. Save readings to watch how it changes over time.")
    }
    private var chartDateRange: ClosedRange<Date> {
        let entries = monitor.deviceHistory
        let first = entries.first?.date ?? Date()
        let last = entries.last?.date ?? first
        let padding = max(3600, last.timeIntervalSince(first) * 0.1)
        if entries.count <= 1 { return first.addingTimeInterval(-43200)...first.addingTimeInterval(43200) }
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }
    private var historyAxisDates: [Date] {
        guard let first = monitor.deviceHistory.first?.date else { return [] }
        guard let last = monitor.deviceHistory.last?.date, !Calendar.current.isDate(first, inSameDayAs: last) else { return [first] }
        return [first, last]
    }
    private var footer: some View {
        HStack(spacing: 10) {
            Circle().fill(s.isPresent ? Palette.green : Color.secondary).frame(width: 5, height: 5)
            Text(s.isPresent ? "Live · \(s.date.formatted(date: .omitted, time: .shortened))" : "Battery unavailable")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Button { monitor.refresh() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Refresh now (⌘R)").accessibilityLabel("Refresh now")
            Button { monitor.refresh(); monitor.saveReading() } label: { Label("Save Reading", systemImage: "plus").font(.system(size: 11, weight: .medium)) }
                .buttonStyle(.bordered).controlSize(.small).disabled(!s.isPresent || s.health == nil)
        }.padding(.horizontal, 20).frame(height: 47).fixedSize(horizontal: false, vertical: true)
    }
    private func capacity(_ value: Int?) -> String { value.map { "\($0.formatted()) mAh" } ?? "Unavailable" }
    private func duration(_ minutes: Int) -> String { minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m" }
}

struct MetricRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.primary.opacity(0.85))
            Spacer(minLength: 12)
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing).textSelection(.enabled)
        }.font(.system(size: 13)).monospacedDigit()
    }
}
struct CapacityBar: View {
    let title: String
    let value: String
    let percentage: Double?
    let color: Color
    var body: some View {
        VStack(spacing: 9) {
            MetricRow(title: title, value: value)
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07))
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 5).fill(color.gradient).frame(width: geometry.size.width * min(1, max(0, (percentage ?? 0) / 100)))
                        Spacer(minLength: 0)
                    }
                    Text(percentage.map { String(format: "%.1f%%", $0) } ?? "Unavailable")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.85))
                }.overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.07)))
            }.frame(height: 25)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(title), \(percentage.map { String(format: "%.1f percent", $0) } ?? "unavailable"), \(value)")
    }
}
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Color.primary.opacity(configuration.isPressed ? 0.13 : 0.065), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}
struct InsightTile: View {
    let symbol: String
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(Palette.green)
            Text(value).font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct MacIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.18)).frame(width: 54, height: 36)
                .overlay {
                    RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Color(red: 0.23, green: 0.66, blue: 0.84), Color(red: 0.13, green: 0.37, blue: 0.59)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(3).overlay(alignment: .top) { Capsule().fill(.black.opacity(0.65)).frame(width: 9, height: 3).padding(.top, 2) }
                }
            UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3).fill(LinearGradient(colors: [.gray.opacity(0.6), .gray], startPoint: .top, endPoint: .bottom)).frame(width: 66, height: 4)
        }.shadow(color: .black.opacity(0.12), radius: 2, y: 2).accessibilityHidden(true)
    }
}

private struct DetailView: View {
    @EnvironmentObject private var monitor: BatteryMonitor
    @Environment(\.dismiss) private var dismiss
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(spacing: 9) {
                Image(systemName: detail == "mac" ? "laptopcomputer" : "battery.100percent").foregroundStyle(Palette.green)
                Text(detail == "mac" ? "Mac Information" : "Battery Information").font(.system(size: 18, weight: .semibold))
            }
            Divider()
            if detail == "mac" {
                MetricRow(title: "Mac", value: monitor.identity.name)
                MetricRow(title: "Model identifier", value: monitor.identity.model)
                MetricRow(title: "Chip", value: monitor.identity.chip)
                MetricRow(title: "Memory", value: monitor.identity.memory)
                MetricRow(title: "macOS", value: monitor.identity.os)
            } else {
                MetricRow(title: "Serial number", value: monitor.snapshot.serial ?? "Unavailable")
                MetricRow(title: "Manufacturer", value: monitor.snapshot.manufacturer ?? "Not reported")
                MetricRow(title: "Manufacture date", value: monitor.snapshot.manufactureDate.map { $0.formatted(date: .numeric, time: .omitted) } ?? "Unavailable")
                MetricRow(title: "Condition", value: monitor.snapshot.condition ?? "Not reported")
                MetricRow(title: "Status", value: monitor.snapshot.status)
                Text("Some Mac models do not expose a battery manufacturer or a readable manufacture date. Unavailable values are left blank rather than estimated.").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 440)
    }
}
