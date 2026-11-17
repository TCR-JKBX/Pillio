import SwiftUI
import PhotosUI

struct LocalPhotoPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (Data) -> Void
        init(onImage: @escaping (Data) -> Void) { self.onImage = onImage }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { [onImage] data, _ in
                guard let data else { return }
                DispatchQueue.main.async { onImage(data) }
            }
        }
    }
}
