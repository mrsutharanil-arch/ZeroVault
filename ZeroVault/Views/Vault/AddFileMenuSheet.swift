//
//  AddFileMenuSheet.swift
//  ZeroVault
//
//  Import sheet offering zero-trace encrypted ingestion options:
//  - Direct-to-RAM Camera
//  - Encrypted Secret Note
//  - File Importer
//  - Photo & Video Importer (Native PHPicker with high-speed AES-256-GCM sealing)
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

public struct AddFileMenuSheet: View {
    @ObservedObject public var vaultVM: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFilePicker: Bool = false
    @State private var showingPhotoPicker: Bool = false
    @State private var isCreatingNote: Bool = false
    @State private var isEncrypting: Bool = false
    @State private var encryptingStatusMessage: String = "Encrypting with AES-256-GCM..."
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert: Bool = false
    
    @State private var noteTitle: String = ""
    @State private var noteBody: String = ""
    
    public init(vaultVM: VaultViewModel) {
        self.vaultVM = vaultVM
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.08, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Security Notice Banner
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ZERO-TRACE ENCRYPTION")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text("All imported files are sealed with AES-256-GCM. Backups and external file manager access are blocked.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Options List
                    VStack(spacing: 12) {
                        // 1. Secure Camera
                        MenuOptionCard(
                            title: "Take Secure Photo / Video",
                            subtitle: "Direct-to-RAM capture. Bypasses Camera Roll and Apple Photos completely.",
                            icon: "camera.fill",
                            color: Color(red: 0.2, green: 0.8, blue: 0.6)
                        ) {
                            dismiss()
                            vaultVM.isShowingCamera = true
                        }
                        
                        // 2. Secret Note
                        MenuOptionCard(
                            title: "Create Secret Encrypted Note",
                            subtitle: "Write confidential text, passwords, or recovery seeds directly into encrypted RAM.",
                            icon: "lock.doc.fill",
                            color: Color(red: 0.8, green: 0.5, blue: 1.0)
                        ) {
                            isCreatingNote = true
                        }
                        
                        // 3. Import File / Document
                        MenuOptionCard(
                            title: "Import File / Document",
                            subtitle: "Import PDF, audio, zip, or document and encrypt immediately.",
                            icon: "doc.badge.plus",
                            color: Color(red: 1.0, green: 0.75, blue: 0.3)
                        ) {
                            showingFilePicker = true
                        }
                        
                        // 4. Import from Camera Roll (Native PHPicker)
                        MenuOptionCard(
                            title: "Import from Camera Roll",
                            subtitle: "Encrypt existing photos & videos with AES-256-GCM and isolate into vault.",
                            icon: "photo.stack.fill",
                            color: Color(red: 0.4, green: 0.7, blue: 1.0)
                        ) {
                            showingPhotoPicker = true
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
                
                // Loading / Encrypting HUD overlay
                if isEncrypting {
                    ZStack {
                        Color.black.opacity(0.8).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                                .scaleEffect(1.5)
                            Text(encryptingStatusMessage)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Sealing in sovereign encrypted storage...")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .padding(28)
                        .background(Color(white: 0.12))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .navigationTitle("Add to ZeroVault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            // File Importer (Documents/PDFs/Archives)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            let data = try Data(contentsOf: url)
                            let filename = url.lastPathComponent
                            let cat: VaultCategory
                            let ext = url.pathExtension.lowercased()
                            if ["jpg", "jpeg", "png", "heic", "webp"].contains(ext) {
                                cat = .photos
                            } else if ["mp4", "mov", "m4v"].contains(ext) {
                                cat = .videos
                            } else if ["pdf", "doc", "docx", "pages", "xls", "xlsx", "txt"].contains(ext) {
                                cat = .documents
                            } else if ["mp3", "m4a", "wav"].contains(ext) {
                                cat = .audio
                            } else if ["zip", "tar", "gz"].contains(ext) {
                                cat = .archives
                            } else {
                                cat = .documents
                            }
                            
                            try vaultVM.importRawData(
                                data: data,
                                originalFilename: filename,
                                category: cat,
                                title: (filename as NSString).deletingPathExtension
                            )
                            vaultVM.loadVaultFiles()
                            dismiss()
                        } catch {
                            self.errorMessage = "Failed to encrypt file: \(error.localizedDescription)"
                            self.showingErrorAlert = true
                        }
                    } else {
                        self.errorMessage = "Permission denied: Could not access security-scoped file URL."
                        self.showingErrorAlert = true
                    }
                case .failure(let error):
                    self.errorMessage = "File selection failed: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                }
            }
            // Native Photos & Videos Picker Sheet
            .sheet(isPresented: $showingPhotoPicker) {
                NativePhotoPickerView(
                    isPresented: $showingPhotoPicker,
                    onItemsPicked: { items in
                        processPickedMedia(items)
                    },
                    onError: { errorText in
                        self.errorMessage = errorText
                        self.showingErrorAlert = true
                    }
                )
            }
            // Secret Note Sheet
            .sheet(isPresented: $isCreatingNote) {
                NavigationStack {
                    ZStack {
                        Color(red: 0.05, green: 0.07, blue: 0.09).ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            TextField("Note Title", text: $noteTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color(white: 0.12))
                                .cornerRadius(10)
                            
                            TextEditor(text: $noteBody)
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(Color(white: 0.12))
                                .cornerRadius(10)
                            
                            Spacer()
                        }
                        .padding(16)
                    }
                    .navigationTitle("New Encrypted Note")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isCreatingNote = false }
                                .foregroundColor(.gray)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save & Seal") {
                                do {
                                    try vaultVM.createSecretNote(title: noteTitle, content: noteBody)
                                    vaultVM.loadVaultFiles()
                                    isCreatingNote = false
                                    dismiss()
                                } catch {
                                    self.errorMessage = "Failed to save secret note: \(error.localizedDescription)"
                                    self.showingErrorAlert = true
                                }
                            }
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .disabled(noteBody.isEmpty)
                        }
                    }
                }
            }
            // Error Alert
            .alert("Import Notice", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {
                    showingErrorAlert = false
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred during import.")
            }
        }
    }
    
    // MARK: - Process Picked Photos & Videos
    
    private func processPickedMedia(_ items: [NativePhotoPickerView.PickedMediaItem]) {
        guard !items.isEmpty else { return }
        isEncrypting = true
        encryptingStatusMessage = "Encrypting \(items.count) item(s) with AES-256-GCM..."
        
        Task {
            var failureCount = 0
            for item in items {
                do {
                    try vaultVM.importRawData(
                        data: item.data,
                        originalFilename: item.filename,
                        category: item.category,
                        title: item.title,
                        userNotes: "Imported securely from Camera Roll."
                    )
                } catch {
                    print("Error importing item \(item.filename): \(error)")
                    failureCount += 1
                }
            }
            
            await MainActor.run {
                vaultVM.loadVaultFiles()
                isEncrypting = false
                if failureCount > 0 && failureCount == items.count {
                    self.errorMessage = "Failed to encrypt selected items."
                    self.showingErrorAlert = true
                } else {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Native UIKit PHPickerViewController Representable

public struct NativePhotoPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onItemsPicked: ([PickedMediaItem]) -> Void
    var onError: (String) -> Void
    
    public struct PickedMediaItem {
        public let data: Data
        public let filename: String
        public let title: String
        public let category: VaultCategory
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // Multi-selection allowed
        config.filter = .any(of: [.images, .videos])
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: NativePhotoPickerView
        
        init(_ parent: NativePhotoPickerView) {
            self.parent = parent
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            guard !results.isEmpty else { return }
            
            Task {
                var loadedItems: [PickedMediaItem] = []
                
                for (index, result) in results.enumerated() {
                    let provider = result.itemProvider
                    let timestamp = Int(Date().timeIntervalSince1970) + index
                    
                    if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        if let item = await loadMovie(provider: provider, timestamp: timestamp) {
                            loadedItems.append(item)
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        if let item = await loadImage(provider: provider, timestamp: timestamp) {
                            loadedItems.append(item)
                        }
                    }
                }
                
                await MainActor.run {
                    if loadedItems.isEmpty {
                        self.parent.onError("Could not extract selected photos or videos. Please verify Photo Library access permissions.")
                    } else {
                        self.parent.onItemsPicked(loadedItems)
                    }
                }
            }
        }
        
        private func loadMovie(provider: NSItemProvider, timestamp: Int) async -> PickedMediaItem? {
            await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    guard let url = url, let data = try? Data(contentsOf: url) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let filename = "Video_\(timestamp).\(ext)"
                    continuation.resume(returning: PickedMediaItem(
                        data: data,
                        filename: filename,
                        title: "Encrypted Video \(timestamp)",
                        category: .videos
                    ))
                }
            }
        }
        
        private func loadImage(provider: NSItemProvider, timestamp: Int) async -> PickedMediaItem? {
            // First attempt: raw data representation (PNG, HEIC, JPEG, etc.)
            let rawData: Data? = await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    continuation.resume(returning: data)
                }
            }
            
            if let data = rawData, !data.isEmpty {
                return PickedMediaItem(
                    data: data,
                    filename: "Photo_\(timestamp).jpg",
                    title: "Encrypted Photo \(timestamp)",
                    category: .photos
                )
            }
            
            // Second attempt: load via UIImage object fallback
            return await withCheckedContinuation { continuation in
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { object, error in
                        if let uiImage = object as? UIImage,
                           let jpegData = uiImage.jpegData(compressionQuality: 0.95) {
                            continuation.resume(returning: PickedMediaItem(
                                data: jpegData,
                                filename: "Photo_\(timestamp).jpg",
                                title: "Encrypted Photo \(timestamp)",
                                category: .photos
                            ))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Menu Option Card Helper
struct MenuOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color(white: 0.1))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(white: 0.16), lineWidth: 1)
            )
        }
    }
}
