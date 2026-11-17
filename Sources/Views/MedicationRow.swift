import SwiftUI
import UIKit

struct MedicationRow: View {
    let medication: Medication
    let photoURL: URL?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let photoURL, let image = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "pills.fill").resizable().scaledToFit().padding(12).foregroundColor(.accentColor).background(Color.accentColor.opacity(0.12))
                }
            }
            .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name).font(.headline).foregroundColor(.primary)
                Text("Stock : \(medication.stock.formatted()) \(medication.unit)").font(.subheadline).foregroundColor(.secondary)
                Text(medication.sortedReminderMinutes.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }.joined(separator: " · ")).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
        }.padding(.vertical, 4)
    }
}
