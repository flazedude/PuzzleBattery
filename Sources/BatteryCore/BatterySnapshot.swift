import Foundation

public struct BatterySnapshot: Codable, Equatable, Sendable {
    public var date: Date
    public var isPresent: Bool
    public var percentage: Double?
    public var currentCapacity: Int?
    public var fullCapacity: Int?
    public var designCapacity: Int?
    public var cycles: Int?
    public var temperature: Double?
    public var voltage: Double?
    public var amperage: Double?
    public var isCharging: Bool
    public var externalConnected: Bool
    public var isFull: Bool
    public var timeRemaining: Int?
    public var adapterWatts: Int?
    public var manufacturer: String?
    public var serial: String?
    public var manufactureDate: Date?
    public var condition: String?
    public var lowPowerMode: Bool

    public var health: Double? {
        guard let fullCapacity, let designCapacity, designCapacity > 0 else { return nil }
        return Double(fullCapacity) / Double(designCapacity) * 100
    }
    public var watts: Double? {
        guard let voltage, let amperage else { return nil }
        return abs(voltage * amperage)
    }
    public var status: String {
        guard isPresent else { return "No internal battery" }
        if isFull { return "Fully charged" }
        if isCharging { return "Charging" }
        return externalConnected ? "Charging paused" : "On battery power"
    }
    public var needsService: Bool {
        condition == "Service Recommended" || condition == "Poor" || condition == "Fair" || (health.map { $0 < 80 } ?? false)
    }

    public static let unavailable = parse(properties: [:])

    /// Apple Silicon often exposes normalized percentages at the root and mAh in BatteryData.
    /// Never treat a normalized MaxCapacity of 100 as the physical capacity.
    public static func parse(properties p: [String: Any], pack: [String: Any] = [:], powerSource ps: [String: Any] = [:], now: Date = Date(), lowPowerMode: Bool = false) -> Self {
        let data = p["BatteryData"] as? [String: Any] ?? [:]
        let packData = pack["BatteryData"] as? [String: Any] ?? [:]
        let sources = [p, data, packData]
        func number(_ keys: [String]) -> Double? {
            for key in keys {
                for source in sources {
                    if let value = source[key] as? NSNumber { return value.doubleValue }
                }
            }
            return nil
        }
        func capacity(_ keys: [String]) -> Int? {
            for key in keys {
                for source in sources {
                    if let value = source[key] as? NSNumber, value.doubleValue > 100, value.doubleValue < 100_000 {
                        return value.intValue
                    }
                }
            }
            return nil
        }
        func flag(_ key: String) -> Bool { (p[key] as? NSNumber)?.boolValue ?? false }
        let full = capacity(["AppleRawMaxCapacity", "FullChargeCapacity", "NominalChargeCapacity", "MaxCapacity"])
        let design = capacity(["DesignCapacity"])
        let psCurrent = (ps["Current Capacity"] as? NSNumber)?.doubleValue
        let psMax = (ps["Max Capacity"] as? NSNumber)?.doubleValue
        var percent: Double?
        if let psCurrent, let psMax, psMax > 0 {
            percent = psCurrent / psMax * 100
        } else if let current = number(["CurrentCapacity"]), let max = number(["MaxCapacity"]), max > 0 {
            percent = current / max * 100
        }
        percent = percent.flatMap { $0.isFinite ? min(100, max(0, $0)) : nil }
        var current = number(["AppleRawCurrentCapacity", "RemainingCapacity"]).flatMap { $0 >= 0 && $0 < 100_000 ? Int($0) : nil }
        if current == nil, let raw = number(["CurrentCapacity"]), raw > 100 { current = Int(raw) }
        if current == nil, let percent, let full { current = Int(Double(full) * percent / 100) }
        var amps = number(["InstantAmperage", "Amperage"])
        // Some drivers encode a negative signed current as an unsigned 32/64-bit number.
        if let raw = amps, raw > Double(Int32.max) {
            let n = sources.compactMap { ($0["InstantAmperage"] ?? $0["Amperage"]) as? NSNumber }.first
            if let n { amps = raw <= Double(UInt32.max) ? Double(Int32(bitPattern: n.uint32Value)) : Double(n.int64Value) }
        }
        let rawTemperature = number(["Temperature"])
        let temperature = rawTemperature.map { $0 / 100 }.flatMap { (-20...100).contains($0) ? $0 : nil }
        let charging = (ps["Is Charging"] as? Bool) ?? flag("IsCharging")
        let external = (ps["Power Source State"] as? String).map { $0 == "AC Power" } ?? flag("ExternalConnected")
        let time = number([charging ? "AvgTimeToFull" : "AvgTimeToEmpty", "TimeRemaining"])
            .flatMap { $0 > 0 && $0 < 65535 ? Int($0) : nil }
        let adapter = p["AdapterDetails"] as? [String: Any]
        var made: Date?
        if let raw = number(["ManufactureDate"]), raw > 0, raw <= 65535 {
            let bits = Int(raw)
            let components = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 1980 + (bits >> 9), month: (bits >> 5) & 15, day: bits & 31)
            if let date = components.date, date <= now, let month = components.month, (1...12).contains(month), let day = components.day, (1...31).contains(day), Calendar(identifier: .gregorian).component(.day, from: date) == day { made = date }
        }
        return Self(
            date: now, isPresent: (ps["Is Present"] as? Bool) ?? (p["BatteryInstalled"] as? Bool) ?? !p.isEmpty,
            percentage: percent, currentCapacity: current, fullCapacity: full, designCapacity: design,
            cycles: number(["CycleCount"]).map(Int.init), temperature: temperature,
            voltage: number(["Voltage", "AppleRawBatteryVoltage"]).map { $0 / 1000 },
            amperage: amps.map { $0 / 1000 }, isCharging: charging, externalConnected: external,
            isFull: flag("FullyCharged"), timeRemaining: time,
            adapterWatts: external ? (adapter?["Watts"] as? NSNumber)?.intValue : nil,
            manufacturer: p["Manufacturer"] as? String,
            serial: (p["BatterySerialNumber"] ?? p["Serial"]) as? String,
            manufactureDate: made, condition: ps["BatteryHealth"] as? String,
            lowPowerMode: lowPowerMode
        )
    }
}

public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var deviceID: String
    public var date: Date
    public var health: Double
    public var fullCapacity: Int
    public var designCapacity: Int
    public var cycles: Int?
    public var percentage: Double?

    public init?(snapshot: BatterySnapshot, deviceID: String) {
        guard snapshot.isPresent, let health = snapshot.health, let full = snapshot.fullCapacity, let design = snapshot.designCapacity else { return nil }
        self.id = UUID()
        self.deviceID = deviceID
        date = snapshot.date
        self.health = health
        fullCapacity = full
        designCapacity = design
        cycles = snapshot.cycles
        percentage = snapshot.percentage
    }

    public static func csv(_ entries: [Self]) -> String {
        let formatter = ISO8601DateFormatter()
        let rows = entries.map { entry in
            [formatter.string(from: entry.date), String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), entry.health), String(entry.fullCapacity), String(entry.designCapacity), entry.cycles.map(String.init) ?? "", entry.percentage.map { String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? ""].joined(separator: ",")
        }
        return (["date,health_percent,full_capacity_mah,design_capacity_mah,cycles,charge_percent"] + rows).joined(separator: "\n") + "\n"
    }
}
