import SwiftUI
import PhotosUI
import AVFoundation

@MainActor
class CameraViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var showingCamera = false
    @Published var showingPhotoPicker = false
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    init() {
        checkCameraPermission()
    }

    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermissionStatus = granted ? .authorized : .denied
    }

    func openCamera() {
        if cameraPermissionStatus == .authorized {
            showingCamera = true
        } else if cameraPermissionStatus == .notDetermined {
            Task {
                await requestCameraPermission()
                if cameraPermissionStatus == .authorized {
                    showingCamera = true
                }
            }
        } else {
            errorMessage = "Camera access is required. Please enable it in Settings."
        }
    }

    func openPhotoPicker() {
        showingPhotoPicker = true
    }

    func handleCapturedImage(_ image: UIImage) {
        let fixedImage = ImageProcessor.fixOrientation(image)
        capturedImage = fixedImage
        showingCamera = false
    }

    func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let fixedImage = ImageProcessor.fixOrientation(image)
                capturedImage = fixedImage
            }
        } catch {
            errorMessage = "Failed to load selected photo"
        }
    }

    var isCameraDenied: Bool {
        cameraPermissionStatus == .denied || cameraPermissionStatus == .restricted
    }

    func clearCapturedImage() {
        capturedImage = nil
        selectedPhotoItem = nil
    }
}
