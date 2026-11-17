import SwiftUI
import UIKit

struct MedicationFormView: View {
    @EnvironmentObject private var store: MedicationStore
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.presentationMode) private var presentationMode
    let medication: Medication?

    @State private var name = ""
    @State private var stock = ""
    @State private var amount = "1"
    @State private var unit = "comprimé(s)"
    @State private var reminderDates: [Date] = [Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()]
    @State private var imageData: Data?
    @State private var showingPhotoPicker = false

    private let units = ["comprimé(s)", "dose(s)", "gélule(s)", "ml", "bouffée(s)", "autre"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Traitement")) {
                    TextField("Nom (obligatoire)", text: $name)
                    Picker("Unité", selection: $unit) { units.forEach { Text($0).tag($0) } }
                    TextField("Stock actuel", text: $stock).keyboardType(.decimalPad)
                    TextField("Quantité par prise", text: $amount).keyboardType(.decimalPad)
                }
                Section(header: Text("Heures de rappel"), footer: Text("Une notification quotidienne sera programmée pour chaque heure.")) {
                    ForEach(reminderDates.indices, id: \.self) { index in
                        DatePicker("Rappel \(index + 1)", selection: $reminderDates[index], displayedComponents: .hourAndMinute)
                    }.onDelete { reminderDates.remove(atOffsets: $0) }
                    Button { reminderDates.append(Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()) } label: { Label("Ajouter une heure", systemImage: "plus") }
                }
                Section(header: Text("Photo du paquet")) {
                    Button { showingPhotoPicker = true } label: { Label(imageData == nil ? "Choisir une photo" : "Photo choisie", systemImage: "photo") }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    } else if let medication, let url = store.photoURL(for: medication), let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    }
                }
            }
            .navigationTitle(medication == nil ? "Nouveau traitement" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reminderDates.isEmpty) }
            }
            .onAppear(perform: loadValues)
            .sheet(isPresented: $showingPhotoPicker) {
                LocalPhotoPicker { data in imageData = data }
            }
        }
    }

    private func loadValues() {
        guard let medication else { return }
        name = medication.name
        stock = String(medication.stock)
        amount = String(medication.amountPerDose)
        unit = medication.unit
        reminderDates = medication.sortedReminderMinutes.map { Calendar.current.date(from: DateComponents(hour: $0 / 60, minute: $0 % 60)) ?? Date() }
    }

    private func save() {
        let parsedStock = Double(stock.replacingOccurrences(of: ",", with: ".")) ?? 0
        let parsedAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 1
        let minutes = Array(Set(reminderDates.map { Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) })).sorted()
        let value = Medication(id: medication?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), stock: max(0, parsedStock), amountPerDose: max(0.01, parsedAmount), unit: unit, reminderMinutes: minutes, photoFilename: medication?.photoFilename)
        store.save(value, imageData: imageData)
        notifications.scheduleDaily(value)
        presentationMode.wrappedValue.dismiss()
    }
}
