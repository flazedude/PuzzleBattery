import Foundation
import Testing
@testable import BatteryCore

@Test func appleSiliconNormalizedCapacity() throws {
    let s = BatterySnapshot.parse(properties: [
        "BatteryInstalled": true, "MaxCapacity": 100, "CurrentCapacity": 70,
        "CycleCount": 217, "ExternalConnected": true, "IsCharging": true,
        "Voltage": 12529, "Amperage": 3117,
        "BatteryData": ["FullChargeCapacity": 5058, "NominalChargeCapacity": 5208, "DesignCapacity": 6075, "RemainingCapacity": 3502]
    ], pack: ["BatteryData": ["Temperature": 2269, "ManufactureDate": 55191138285874]])
    #expect(s.fullCapacity == 5058)
    #expect(s.designCapacity == 6075)
    #expect(s.currentCapacity == 3502)
    #expect(s.percentage == 70)
    #expect(abs(try #require(s.health) - 83.259) < 0.01)
    #expect(s.temperature == 22.69)
    #expect(s.manufactureDate == nil)
    #expect(s.status == "Charging")
    #expect(abs(try #require(s.watts) - 39.052893) < 0.001)
}

@Test func intelRawCapacityAndUnsignedCurrent() throws {
    let s = BatterySnapshot.parse(properties: [
        "BatteryInstalled": true, "CurrentCapacity": 4000, "MaxCapacity": 5000, "DesignCapacity": 6000,
        "Amperage": NSNumber(value: UInt64.max - 999), "Voltage": 12000,
        "Temperature": 3000, "CycleCount": 440, "AvgTimeToEmpty": 120
    ])
    #expect(s.percentage == 80)
    #expect(s.currentCapacity == 4000)
    #expect(s.fullCapacity == 5000)
    #expect(s.amperage == -1)
    #expect(s.watts == 12)
    #expect(s.timeRemaining == 120)
    #expect(s.status == "On battery power")
}

@Test func publicPowerSourcePercentageTakesPrecedence() {
    let s = BatterySnapshot.parse(properties: ["MaxCapacity": 100, "CurrentCapacity": 73, "IsCharging": true], powerSource: ["Current Capacity": 80, "Max Capacity": 100, "Is Charging": false, "Power Source State": "AC Power"])
    #expect(s.percentage == 80)
    #expect(s.status == "Charging paused")
    #expect(s.fullCapacity == nil)
    #expect(s.health == nil)
}

@Test func missingBatteryAndInvalidReadings() {
    let s = BatterySnapshot.unavailable
    #expect(!s.isPresent)
    #expect(s.percentage == nil)
    #expect(s.health == nil)
    #expect(HistoryEntry(snapshot: s, deviceID: "test") == nil)
    let invalid = BatterySnapshot.parse(properties: ["Temperature": 65535, "AvgTimeToEmpty": 65535, "MaxCapacity": 0, "CurrentCapacity": 0])
    #expect(invalid.timeRemaining == nil)
    #expect(invalid.temperature == nil)
    #expect(invalid.percentage == nil)
}

@Test func historyRoundTripAndCSV() throws {
    let s = BatterySnapshot.parse(properties: ["BatteryInstalled": true, "MaxCapacity": 5000, "CurrentCapacity": 2500, "DesignCapacity": 6250, "CycleCount": 123])
    let entry = try #require(HistoryEntry(snapshot: s, deviceID: "mac-a"))
    let restored = try JSONDecoder().decode(HistoryEntry.self, from: JSONEncoder().encode(entry))
    #expect(restored == entry)
    #expect(restored.health == 80)
    #expect(restored.deviceID == "mac-a")
    let csv = HistoryEntry.csv([entry])
    #expect(csv.contains("80.00,5000,6250,123,50.0"))
    #expect(csv.split(separator: "\n").count == 2)
}

@Test func validSMBusDate() {
    let encoded = ((2024 - 1980) << 9) | (10 << 5) | 17
    let s = BatterySnapshot.parse(properties: ["ManufactureDate": encoded])
    let calendar = Calendar(identifier: .gregorian)
    #expect(s.manufactureDate.map { calendar.component(.year, from: $0) } == 2024)
    #expect(s.manufactureDate.map { calendar.component(.month, from: $0) } == 10)
    #expect(s.manufactureDate.map { calendar.component(.day, from: $0) } == 17)
}
