import SwiftUI
import PhotosUI
import SwiftData

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var analysisViewModel = AnalysisViewModel()
    @State private var showingAnalysis = false
    @State private var showingError = false
    @State private var showingManualLog = false
    @Query private var entries: [MealEntry]

    init() {
        _entries = Query(
            filter: MealEntry.currentUserScope(MealEntry.currentUserIdFromKeychain),
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = viewModel.capturedImage {
                    capturedImageView(image)
                } else {
                    placeholderView
                }

                actionButtons
            }
            .padding()
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showingCamera) {
                ImagePicker(image: $viewModel.capturedImage)
            }
            .photosPicker(
                isPresented: $viewModel.showingPhotoPicker,
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            )
            .onChange(of: viewModel.selectedPhotoItem) { _, _ in
                Task {
                    await viewModel.loadSelectedPhoto()
                }
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showingError = newValue != nil
            }
            .navigationDestination(isPresented: $showingAnalysis) {
                if let image = viewModel.capturedImage {
                    AnalysisView(
                        image: image,
                        viewModel: analysisViewModel,
                        onDismiss: {
                            viewModel.clearCapturedImage()
                            analysisViewModel.reset()
                            showingAnalysis = false
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showingManualLog) {
                ManualFoodLogView(entries: entries)
            }
            .alert("Camera Access Required", isPresented: Binding(
                get: { showingError && viewModel.isCameraDenied },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("Open Settings") {
                    viewModel.errorMessage = nil
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text("Please enable camera access in Settings so you can take food photos.")
            }
            .alert("Error", isPresented: Binding(
                get: { showingError && !viewModel.isCameraDenied },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func capturedImageView(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 350)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 5)
                .accessibilityLabel("Captured food photo")

            HStack(spacing: 16) {
                Button {
                    viewModel.clearCapturedImage()
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Retake photo")

                Button {
                    showingAnalysis = true
                    Task {
                        await analysisViewModel.analyzeImage(image)
                    }
                } label: {
                    Label("Analyze", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("Analyze food for calories")
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green.opacity(0.7))
                .accessibilityHidden(true)

            Text("Capture or select a food image")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("We'll analyze it and estimate calories")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxHeight: 350)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.openCamera()
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel("Open camera to take a photo")

            Button {
                viewModel.openPhotoPicker()
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Choose photo from library")

            HStack {
                Rectangle()
                    .fill(.tertiary)
                    .frame(height: 0.5)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Rectangle()
                    .fill(.tertiary)
                    .frame(height: 0.5)
            }

            Button {
                showingManualLog = true
            } label: {
                Label("Log Food Manually", systemImage: "pencil.and.list.clipboard")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Log food manually without a photo")
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = ImageProcessor.fixOrientation(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CameraView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
