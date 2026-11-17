import SwiftUI

@main
struct PillioApp: App {
    @StateObject private var store = MedicationStore()
    @StateObject private var notifications = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(notifications)
                .onAppear {
                    notifications.configure { medicationID in
                        // The view owns the prompt state; setting the ID also records this as the active reminder.
                        store.requestConfirmation(for: medicationID)
                    }
                    notifications.requestAuthorization()
                    notifications.refreshAll(for: store.medications)
                }
        }
    }
}

