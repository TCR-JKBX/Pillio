import Foundation
import Combine
import UIKit

final class MedicationStore: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var groups: [MedicationGroup] = []
    @Published var pendingConfirmation: UUID?
    @Published private(set) var pendingConfirmationScheduledAt: Date?

    private let fileURL: URL
    private let groupsFileURL: URL
    private let handledDosesURL: URL
    private let photosDirectory: URL
    private struct DoseOccurrence {
        let medicationID: UUID
        let scheduledAt: Date
        let reminderMinutes: Int
        let key: String
    }
    private var handledDoseKeys = Set<String>()
    private var queuedOccurrences: [DoseOccurrence] = []
    private var currentOccurrence: DoseOccurrence?

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("medications.json")
        groupsFileURL = documents.appendingPathComponent("medication-groups.json")
        handledDosesURL = documents.appendingPathComponent("handled-doses.json")
        photosDirectory = documents.appendingPathComponent("MedicationPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        load()
        loadGroups()
        loadHandledDoses()
    }

    func photoURL(for medication: Medication) -> URL? {
        guard let filename = medication.photoFilename else { return nil }
        return photosDirectory.appendingPathComponent(filename)
    }

    func requestConfirmation(for id: UUID) {
        guard let medication = medications.first(where: { $0.id == id }) else { return }
        let now = Date()
        let scheduledOccurrence = latestOccurrence(for: medication, before: now)
        // Queue every overdue dose first so a late-tapped notification cannot
        // jump ahead of an earlier reminder that is still unanswered.
        checkForMissedDoses(at: now)

        if let scheduledOccurrence, handledDoseKeys.contains(scheduledOccurrence.key) {
            // A snoozed reminder is a new prompt, even when the original dose was
            // already acknowledged as missed.
            let snoozedOccurrence = DoseOccurrence(
                medicationID: medication.id,
                scheduledAt: now,
                reminderMinutes: Calendar.current.component(.hour, from: now) * 60
                    + Calendar.current.component(.minute, from: now),
                key: "notification|\(medication.id.uuidString)|\(UUID().uuidString)"
            )
            enqueue(snoozedOccurrence)
        }
        presentNextConfirmation()
    }

    func checkForMissedDoses(at now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        for medication in medications {
            for minutes in medication.sortedReminderMinutes {
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                components.hour = minutes / 60
                components.minute = minutes % 60
                guard let scheduledAt = calendar.date(from: components), scheduledAt <= now else { continue }
                enqueue(makeOccurrence(medicationID: medication.id, date: scheduledAt, minutes: minutes))
            }
        }

        presentNextConfirmation()
    }

    func save(_ medication: Medication, imageData: Data? = nil) {
        var value = medication
        if let imageData {
            let filename = "\(value.id.uuidString).jpg"
            let url = photosDirectory.appendingPathComponent(filename)
            if let image = UIImage(data: imageData), let jpeg = image.jpegData(compressionQuality: 0.82) {
                try? jpeg.write(to: url, options: .atomic)
                value.photoFilename = filename
            }
        }
        if let index = medications.firstIndex(where: { $0.id == value.id }) {
            medications[index] = value
        } else {
            medications.append(value)
        }
        persist()
    }

    func delete(_ medication: Medication) {
        medications.removeAll { $0.id == medication.id }
        if let filename = medication.photoFilename {
            try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(filename))
        }
        persist()
        queuedOccurrences.removeAll { $0.medicationID == medication.id }
        if currentOccurrence?.medicationID == medication.id {
            currentOccurrence = nil
            pendingConfirmation = nil
            pendingConfirmationScheduledAt = nil
            presentNextConfirmation()
        }
    }

    func saveGroup(_ group: MedicationGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        persistGroups()
    }

    func deleteGroup(_ group: MedicationGroup) {
        groups.removeAll { $0.id == group.id }
        for index in medications.indices where medications[index].groupID == group.id {
            medications[index].groupID = nil
        }
        persist()
        persistGroups()
    }

    func moveMedication(_ medicationID: UUID, to groupID: UUID?) {
        guard let index = medications.firstIndex(where: { $0.id == medicationID }) else { return }
        medications[index].groupID = groupID
        persist()
    }

    func confirmTaken(_ id: UUID) {
        guard let index = medications.firstIndex(where: { $0.id == id }) else { return }
        medications[index].stock = max(0, medications[index].stock - medications[index].amountPerDose)
        persist()
        finishCurrentOccurrence()
    }

    func dismissConfirmation(advance: Bool = true) {
        guard currentOccurrence != nil else { return }
        finishCurrentOccurrence(advance: advance)
    }

    func resumePendingConfirmations() {
        presentNextConfirmation()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Medication].self, from: data) else { return }
        medications = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(medications) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadGroups() {
        guard let data = try? Data(contentsOf: groupsFileURL),
              let decoded = try? JSONDecoder().decode([MedicationGroup].self, from: data) else { return }
        groups = decoded
    }

    private func persistGroups() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        try? data.write(to: groupsFileURL, options: .atomic)
    }

    private func latestOccurrence(for medication: Medication, before date: Date) -> DoseOccurrence? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let occurrences = medication.sortedReminderMinutes.compactMap { minutes -> DoseOccurrence? in
            var components = calendar.dateComponents([.year, .month, .day], from: today)
            components.hour = minutes / 60
            components.minute = minutes % 60
            guard let scheduledAt = calendar.date(from: components), scheduledAt <= date else { return nil }
            return makeOccurrence(medicationID: medication.id, date: scheduledAt, minutes: minutes)
        }
        return occurrences.max(by: { $0.scheduledAt < $1.scheduledAt })
    }

    private func makeOccurrence(medicationID: UUID, date: Date, minutes: Int) -> DoseOccurrence {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return DoseOccurrence(
            medicationID: medicationID,
            scheduledAt: date,
            reminderMinutes: minutes,
            key: "\(medicationID.uuidString)|\(day)|\(minutes)"
        )
    }

    private func enqueue(_ occurrence: DoseOccurrence) {
        guard !handledDoseKeys.contains(occurrence.key),
              currentOccurrence?.key != occurrence.key,
              !queuedOccurrences.contains(where: { $0.key == occurrence.key }) else { return }
        queuedOccurrences.append(occurrence)
        queuedOccurrences.sort { $0.scheduledAt < $1.scheduledAt }
    }

    private func presentNextConfirmation() {
        guard pendingConfirmation == nil, currentOccurrence == nil,
              !queuedOccurrences.isEmpty else { return }
        let occurrence = queuedOccurrences.removeFirst()
        guard medications.contains(where: { $0.id == occurrence.medicationID }) else {
            presentNextConfirmation()
            return
        }
        currentOccurrence = occurrence
        pendingConfirmation = occurrence.medicationID
        pendingConfirmationScheduledAt = occurrence.scheduledAt
    }

    private func finishCurrentOccurrence(advance: Bool = true) {
        if let occurrence = currentOccurrence {
            handledDoseKeys.insert(occurrence.key)
            persistHandledDoses()
        }
        currentOccurrence = nil
        pendingConfirmation = nil
        pendingConfirmationScheduledAt = nil
        guard advance else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.presentNextConfirmation()
        }
    }

    private func loadHandledDoses() {
        guard let data = try? Data(contentsOf: handledDosesURL),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        handledDoseKeys = decoded
    }

    private func persistHandledDoses() {
        guard let data = try? JSONEncoder().encode(handledDoseKeys) else { return }
        try? data.write(to: handledDosesURL, options: .atomic)
    }
}

