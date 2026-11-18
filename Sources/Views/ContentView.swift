import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: MedicationStore
    @EnvironmentObject private var notifications: NotificationManager
    @State private var showingNewMedication = false
    @State private var showingNewGroup = false
    @State private var editingMedication: Medication?
    @State private var editingGroup: MedicationGroup?
    @State private var snoozeDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
    @State private var showSnoozePicker = false
    @State private var lastOpenedMedication: UUID?

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
                        Section {
                            ForEach(medications(in: nil)) { medicationRow($0) }
                        } header: { Text("Sans groupe") }

                        ForEach(store.groups) { group in
                            Section {
                                let groupMedications = medications(in: group.id)
                                if groupMedications.isEmpty {
                                    Label("Aucun médicament dans ce groupe", systemImage: "pills")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(groupMedications) { medicationRow($0) }
                                }
                            } header: {
                                HStack {
                                    Text(group.name)
                                    Spacer()
                                    Button { editingGroup = group } label: {
                                        Image(systemName: "ellipsis.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Options du groupe \(group.name)")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pillio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showingNewMedication = true } label: { Label("Ajouter un médicament", systemImage: "pills") }
                        Button { showingNewGroup = true } label: { Label("Créer un groupe", systemImage: "folder.badge.plus") }
                            .disabled(store.medications.isEmpty)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Ajouter")
                }
            }
            .sheet(isPresented: $showingNewMedication) { MedicationFormView(medication: nil) }
            .sheet(item: $editingMedication) { MedicationFormView(medication: $0) }
            .sheet(isPresented: $showingNewGroup) { MedicationGroupFormView(group: nil) }
            .sheet(item: $editingGroup) { MedicationGroupFormView(group: $0) }
            .onChange(of: store.medications) { medications in notifications.refreshAll(for: medications) }
            .alert(item: confirmationBinding) { medication in
                Alert(title: Text("Avez-vous pris \(medication.name) ?"),
                      message: Text(confirmationMessage(for: medication)),
                      primaryButton: .default(Text("Oui")) {
                        store.confirmTaken(medication.id)
                        notifications.scheduleDaily(medication)
                      },
                      secondaryButton: .default(Text("Non")) {
                        lastOpenedMedication = medication.id
                        snoozeDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
                        showSnoozePicker = true
                        store.dismissConfirmation(advance: false)
                      })
            }
            .sheet(isPresented: $showSnoozePicker) { snoozeSheet }
            .onAppear {
                notifications.refreshAll(for: store.medications)
                store.checkForMissedDoses()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.checkForMissedDoses()
                }
            }
            .onChange(of: showSnoozePicker) { isPresented in
                if !isPresented {
                    store.resumePendingConfirmations()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func medications(in groupID: UUID?) -> [Medication] {
        store.medications.filter { $0.groupID == groupID }
    }

    private func medicationRow(_ medication: Medication) -> some View {
        Button { editingMedication = medication } label: {
            MedicationRow(medication: medication, photoURL: store.photoURL(for: medication))
        }
        .buttonStyle(.plain)
    }

    private func deleteMedication(_ medication: Medication) {
        store.delete(medication)
        notifications.removeNotifications(for: medication.id)
    }

    private var confirmationBinding: Binding<Medication?> {
        Binding(
            get: { store.medications.first { $0.id == store.pendingConfirmation } },
            set: { value in
                if value == nil {
                    store.dismissConfirmation(advance: !showSnoozePicker)
                }
            }
        )
    }

    private func confirmationMessage(for medication: Medication) -> String {
        let stock = "Stock actuel : \(medication.stock.formatted()) \(medication.unit)"
        guard let scheduledAt = store.pendingConfirmationScheduledAt else { return stock }
        let time = scheduledAt.formatted(date: .omitted, time: .shortened)
        return "Rappel de \(time). \(stock)"
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
                        if let id = lastOpenedMedication, let medication = store.medications.first(where: { $0.id == id }) {
                            notifications.snooze(medication, until: snoozeDate)
                        }
                        showSnoozePicker = false
                    }
                }
            }
        }
    }
}
