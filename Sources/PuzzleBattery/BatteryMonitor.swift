import AppKit
import BatteryCore
import IOKit
import IOKit.ps
import SwiftUI

struct MacIdentity {
    var name: String
    var model: String
    var chip: String
    var memory: String
    var os: String
    var deviceID: String

    static func read() -> Self {
        func sysctl(_ key: String) -> String {
            var size = 0
            guard sysctlbyname(key, nil, &size, nil, 0) == 0 else { return "Unknown" }
            var bytes = [CChar](repeating: 0, count: size)
            guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { return "Unknown" }
            return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        let model = sysctl("hw.model")
        let platform = BatteryReader.properties(for: "IOPlatformExpertDevice")
        let id = platform["IOPlatformUUID"] as? String ?? model
        return Self(name: model.contains("Book") ? (model.contains("Air") ? "MacBook Air" : "MacBook Pro") : "This Mac", model: model, chip: sysctl("machdep.cpu.brand_string"), memory: "\(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) GB", os: ProcessInfo.processInfo.operatingSystemVersionString, deviceID: id)
    }
}

enum BatteryReader {
    static func properties(for service: String) -> [String: Any] {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(service))
        guard entry != 0 else { return [:] }
        defer { IOObjectRelease(entry) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return [:] }
        return properties?.takeRetainedValue() as? [String: Any] ?? [:]
    }

    static func read() -> BatterySnapshot {
        var description: [String: Any] = [:]
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in list {
                if let candidate = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any], candidate["Type"] as? String == "InternalBattery" {
                    description = candidate
                    break
                }
            }
        }
        return .parse(properties: properties(for: "AppleSmartBattery"), pack: properties(for: "AppleSmartBatteryPack"), powerSource: description, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published var snapshot = BatterySnapshot.unavailable
    @Published var history: [HistoryEntry] = []
    @Published var message: String?
    @Published var identity = MacIdentity.read()
    @AppStorage("automaticHistory") var automaticHistory = true
    @AppStorage("refreshInterval") var refreshInterval = 30.0
    private var timer: Timer?
    private let storageURL: URL
    private var hasUnreadableHistory = false

    init() {
        storageURL = URL.applicationSupportDirectory.appending(path: "PuzzleBattery/history.json")
        loadHistory()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, Date().timeIntervalSince(self.snapshot.date) >= self.refreshInterval else { return }
                self.refresh()
            }
        }
    }

    var deviceHistory: [HistoryEntry] { history.filter { $0.deviceID == identity.deviceID }.sorted { $0.date < $1.date } }

    func refresh() {
        snapshot = BatteryReader.read()
        if automaticHistory, deviceHistory.last.map({ !Calendar.current.isDate($0.date, inSameDayAs: Date()) }) ?? true {
            saveReading(announce: false)
        }
    }

    func saveReading(announce: Bool = true) {
        guard !hasUnreadableHistory else { message = "The history file could not be read. To protect your existing records, it has not been overwritten."; return }
        guard let entry = HistoryEntry(snapshot: snapshot, deviceID: identity.deviceID) else {
            if announce { message = "Battery capacity is unavailable, so this reading cannot be saved." }
            return
        }
        // Avoid identical duplicate records when Save is clicked repeatedly.
        if let last = deviceHistory.last, entry.date.timeIntervalSince(last.date) < 60 {
            if announce { message = "A reading was already saved within the last minute." }
            return
        }
        var updated = history
        updated.append(entry)
        persist(updated, success: announce ? "Battery reading saved." : nil)
    }

    func deleteHistory() { persist(history.filter { $0.deviceID != identity.deviceID }, success: "History cleared for this Mac.") }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do { history = try JSONDecoder().decode([HistoryEntry].self, from: Data(contentsOf: storageURL)) }
        catch { hasUnreadableHistory = true; message = "Saved history could not be read. The original file has been preserved at \(storageURL.path)." }
    }

    private func persist(_ entries: [HistoryEntry], success: String?) {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: storageURL, options: .atomic)
            history = entries
            if let success { message = success }
        } catch { message = "Could not save history: \(error.localizedDescription)" }
    }

    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "PuzzleBattery-History.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try HistoryEntry.csv(deviceHistory).write(to: url, atomically: true, encoding: .utf8) }
        catch { message = "Export failed: \(error.localizedDescription)" }
    }

    func copyReport() {
        let s = snapshot
        let report = """
        PuzzleBattery report — \(s.date.formatted())
        \(identity.name) (\(identity.model)) · \(identity.chip) · \(identity.memory)
        Charge: \(s.percentage.map { String(format: "%.0f%%", $0) } ?? "Unavailable")
        Battery health: \(s.health.map { String(format: "%.1f%%", $0) } ?? "Unavailable")
        Full charge capacity: \(s.fullCapacity.map { "\($0) mAh" } ?? "Unavailable")
        Design capacity: \(s.designCapacity.map { "\($0) mAh" } ?? "Unavailable")
        Charge cycles: \(s.cycles.map(String.init) ?? "Unavailable")
        Temperature: \(s.temperature.map { String(format: "%.1f °C", $0) } ?? "Unavailable")
        Status: \(s.status)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        message = "Battery report copied."
    }
}
