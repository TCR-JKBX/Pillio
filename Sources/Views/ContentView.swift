import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MedicationStore
    @EnvironmentObject private var notifications: NotificationManager
    @State private var showingNewMedication = false
    @State private var editingMedication: Medication?
    @State private var snoozeDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)

    var body: some View {
        NavigationView {
            Group {
                if store.medications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "pills.circle").font(.system(size: 54)).foregroundColor(.accentColor)
                        Text("Aucun traitement").font(.title2.bold())
                        Text("Ajoutez un traitement pour programmer vos rappels.").multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button("Ajouter un traitement") { showingNewMedication = true }.buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    List {
                        ForEach(store.medications) { medication in
                            Button { editingMedication = medication } label: { MedicationRow(medication: medication, photoURL: store.photoURL(for: medication)) }
                                .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { store.medications[$0] }.forEach { medication in
                                store.delete(medication)
                                notifications.removeNotifications(for: medication.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mes traitements")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingNewMedication = true } label: { Image(systemName: "plus") }.accessibilityLabel("Ajouter") } }
            .sheet(isPresented: $showingNewMedication) { MedicationFormView(medication: nil) }
            .sheet(item: $editingMedication) { MedicationFormView(medication: $0) }
            .onChange(of: store.medications) { medications in notifications.refreshAll(for: medications) }
            .alert(item: confirmationBinding) { medication in
                Alert(title: Text("Avez-vous pris \(medication.name) ?"),
                      message: Text("Stock actuel : \(medication.stock.formatted()) \(medication.unit)"),
                      primaryButton: .default(Text("Oui")) {
                        store.confirmTaken(medication.id)
                        notifications.scheduleDaily(medication)
                      },
                      secondaryButton: .default(Text("Non")) { lastOpenedMedication = medication.id; snoozeDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800); store.dismissConfirmation(); showSnoozePicker = true })
            }
            .sheet(isPresented: $showSnoozePicker) { snoozeSheet }
            .onAppear { notifications.refreshAll(for: store.medications) }
        }
        .navigationViewStyle(.stack)
    }

    @State private var showSnoozePicker = false
    private var confirmationBinding: Binding<Medication?> {
        Binding(get: { store.medications.first { $0.id == store.pendingConfirmation } }, set: { if $0 == nil { store.dismissConfirmation() } })
    }

    private var snoozeSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Reporter ce rappel")) {
                    DatePicker("Me le rappeler", selection: $snoozeDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Button("Dans 30 minutes") { snoozeDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800) }
                }
            }
            .navigationTitle("Rappel ultérieur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showSnoozePicker = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Programmer") {
                        if let id = lastOpenedMedication, let medication = store.medications.first(where: { $0.id == id }) { notifications.snooze(medication, until: snoozeDate) }
                        showSnoozePicker = false
                    }
                }
            }
        }
    }

    @State private var lastOpenedMedication: UUID?
}
