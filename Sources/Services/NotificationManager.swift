import Foundation
import Combine
import UserNotifications

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var openMedication: ((UUID) -> Void)?
    private var pendingMedicationIDs: [UUID] = []
    private let categoryID = "MEDICATION_REMINDER"
    private let openActionID = "OPEN_MEDICATION"

    override init() {
        super.init()
        // Register before the first screen appears so taps that launch the app
        // from a terminated state are not lost.
        center.delegate = self
    }

    func configure(openMedication: @escaping (UUID) -> Void) {
        self.openMedication = openMedication
        center.delegate = self
        let waitingIDs = pendingMedicationIDs
        pendingMedicationIDs.removeAll()
        waitingIDs.forEach { deliverOpen(for: $0) }
        let open = UNNotificationAction(identifier: openActionID, title: "Ouvrir", options: [.foreground])
        let category = UNNotificationCategory(identifier: categoryID, actions: [open], intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func refreshAll(for medications: [Medication]) {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { medications.forEach { self?.scheduleDaily($0) } }
        }
    }

    func scheduleDaily(_ medication: Medication) {
        let prefix = medication.id.uuidString
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let requestsToRemove = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: requestsToRemove)
            for minutes in medication.sortedReminderMinutes {
                let content = UNMutableNotificationContent()
                content.title = "Rappel de traitement"
                content.body = "C’est l’heure de prendre \(medication.name)."
                content.sound = .default
                content.categoryIdentifier = self.categoryID
                content.userInfo = ["medicationID": medication.id.uuidString]
                let trigger = UNCalendarNotificationTrigger(dateMatching: medication.dateComponents(for: minutes), repeats: true)
                let request = UNNotificationRequest(identifier: "\(prefix)-daily-\(minutes)", content: content, trigger: trigger)
                self.center.add(request)
            }
        }
    }

    func removeNotifications(for id: UUID) {
        let prefix = id.uuidString
        center.getPendingNotificationRequests { [weak self] pending in
            let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            self?.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func snooze(_ medication: Medication, until date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Rappel de traitement"
        content.body = "Pensez à prendre \(medication.name)."
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = ["medicationID": medication.id.uuidString]
        let seconds = max(60, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "\(medication.id.uuidString)-snooze", content: content, trigger: trigger)
        center.add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard let rawID = response.notification.request.content.userInfo["medicationID"] as? String,
              let id = UUID(uuidString: rawID) else { return }
        DispatchQueue.main.async { self.deliverOpen(for: id) }
    }

    private func deliverOpen(for id: UUID) {
        guard let openMedication else {
            pendingMedicationIDs.append(id)
            return
        }
        openMedication(id)
    }
}

