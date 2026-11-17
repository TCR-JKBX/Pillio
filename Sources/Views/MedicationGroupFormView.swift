import SwiftUI

struct MedicationGroupFormView: View {
    @EnvironmentObject private var store: MedicationStore
    @Environment(\.presentationMode) private var presentationMode

    let group: MedicationGroup?

    @State private var name = ""
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Groupe")) {
                    TextField("Nom du groupe", text: $name)
                }

                if group != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Supprimer ce groupe", systemImage: "trash")
                        }
                    } footer: {
                        Text("Les médicaments du groupe resteront dans Pillio, dans « Sans groupe ».")
                    }
                }
            }
            .navigationTitle(
                group == nil ? "Nouveau groupe" : "Options du groupe"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = group?.name ?? ""
            }
            .confirmationDialog(
                "Supprimer ce groupe ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    "Supprimer définitivement",
                    role: .destructive,
                    action: deleteGroup
                )

                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les médicaments ne seront pas supprimés.")
            }
        }
    }

    private func save() {
        let value = MedicationGroup(
            id: group?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        store.saveGroup(value)
        presentationMode.wrappedValue.dismiss()
    }

    private func deleteGroup() {
        guard let group else { return }

        store.deleteGroup(group)
        presentationMode.wrappedValue.dismiss()
    }
}
