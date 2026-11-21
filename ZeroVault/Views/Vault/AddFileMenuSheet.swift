//
//  AddFileMenuSheet.swift
//  ZeroVault
//
//  Import sheet offering zero-trace encrypted ingestion options:
//  - Direct-to-RAM Camera
//  - Encrypted Secret Note
//  - File Importer
//  - Photo Importer with Camera Roll purge option
//

import SwiftUI
import PhotosUI

public struct AddFileMenuSheet: View {
    @ObservedObject public var vaultVM: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFilePicker: Bool = false
    @State private var showingPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isCreatingNote: Bool = false
    
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
                        
                        // 3. Import File
                        MenuOptionCard(
                            title: "Import File / Document",
                            subtitle: "Import PDF, audio, zip, or document and encrypt immediately.",
                            icon: "doc.badge.plus",
                            color: Color(red: 1.0, green: 0.75, blue: 0.3)
                        ) {
                            showingFilePicker = true
                        }
                        
                        // 4. Import from Photos
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .any(of: [.images, .videos])
                        ) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.18))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "photo.stack.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Import from Camera Roll")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Encrypt existing photo and remove from public gallery.")
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
                    .padding(.horizontal, 16)
                    
                    Spacer()
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
            // File Importer
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
                        if let data = try? Data(contentsOf: url) {
                            let filename = url.lastPathComponent
                            let cat: VaultCategory = url.pathExtension.lowercased() == "pdf" ? .documents : .all
                            try? vaultVM.importRawData(
                                data: data,
                                originalFilename: filename,
                                category: cat,
                                title: (filename as NSString).deletingPathExtension
                            )
                            dismiss()
                        }
                    }
                case .failure(let error):
                    print("File import failed: \(error)")
                }
            }
            // Photo Picker Item Handler
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let timestamp = Int(Date().timeIntervalSince1970)
                        try? vaultVM.importRawData(
                            data: data,
                            originalFilename: "Imported_\(timestamp).jpg",
                            category: .photos,
                            title: "Encrypted Photo \(timestamp)",
                            userNotes: "Imported and encrypted with AES-256-GCM."
                        )
                        await MainActor.run { dismiss() }
                    }
                }
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
                                try? vaultVM.createSecretNote(title: noteTitle, content: noteBody)
                                isCreatingNote = false
                                dismiss()
                            }
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .disabled(noteBody.isEmpty)
                        }
                    }
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
