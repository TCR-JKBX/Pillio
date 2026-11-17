import Foundation
import Combine
import UIKit

final class MedicationStore: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var groups: [MedicationGroup] = []
    @Published var pendingConfirmation: UUID?

    private let fileURL: URL
    private let groupsFileURL: URL
    private let photosDirectory: URL

    init() {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        fileURL = documents.appendingPathComponent("medications.json")
        groupsFileURL = documents.appendingPathComponent("medication-groups.json")
        photosDirectory = documents.appendingPathComponent(
            "MedicationPhotos",
            isDirectory: true
        )

        try? FileManager.default.createDirectory(
            at: photosDirectory,
            withIntermediateDirectories: true
        )

        load()
        loadGroups()
    }

    func photoURL(for medication: Medication) -> URL? {
        guard let filename = medication.photoFilename else {
            return nil
        }

        return photosDirectory.appendingPathComponent(filename)
    }

    func requestConfirmation(for id: UUID) {
        guard medications.contains(where: { $0.id == id }) else {
            return
        }

        pendingConfirmation = id
    }

    func save(_ medication: Medication, imageData: Data? = nil) {
        var value = medication

        if let imageData {
            let filename = "\(value.id.uuidString).jpg"
            let url = photosDirectory.appendingPathComponent(filename)

            if let image = UIImage(data: imageData),
               let jpeg = image.jpegData(compressionQuality: 0.82) {
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
            let photoURL = photosDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: photoURL)
        }

        persist()
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

        for index in medications.indices
        where medications[index].groupID == group.id {
            medications[index].groupID = nil
        }

        persist()
        persistGroups()
    }

    func moveMedication(_ medicationID: UUID, to groupID: UUID?) {
        guard let index = medications.firstIndex(where: {
            $0.id == medicationID
        }) else {
            return
        }

        medications[index].groupID = groupID
        persist()
    }

    func confirmTaken(_ id: UUID) {
        guard let index = medications.firstIndex(where: { $0.id == id }) else {
            return
        }

        medications[index].stock = max(
            0,
            medications[index].stock - medications[index].amountPerDose
        )

        persist()
        pendingConfirmation = nil
    }

    func dismissConfirmation() {
        pendingConfirmation = nil
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Medication].self, from: data) else {
            return
        }

        medications = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(medications) else {
            return
        }

        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadGroups() {
        guard let data = try? Data(contentsOf: groupsFileURL),
              let decoded = try? JSONDecoder().decode([MedicationGroup].self, from: data) else {
            return
        }

        groups = decoded
    }

    private func persistGroups() {
        guard let data = try? JSONEncoder().encode(groups) else {
            return
        }

        try? data.write(to: groupsFileURL, options: .atomic)
    }
}
