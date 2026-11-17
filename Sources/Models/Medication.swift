import Foundation

struct Medication: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var stock: Double
    var amountPerDose: Double
    var unit: String
    /// Minutes après minuit.
    var reminderMinutes: [Int]
    var photoFilename: String?
    var groupID: UUID? = nil

    var sortedReminderMinutes: [Int] {
        reminderMinutes.sorted()
    }

    func dateComponents(for minutes: Int) -> DateComponents {
        DateComponents(hour: minutes / 60, minute: minutes % 60)
    }
}

struct MedicationGroup: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
}
