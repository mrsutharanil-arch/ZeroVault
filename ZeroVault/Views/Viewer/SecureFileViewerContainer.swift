//
//  SecureFileViewerContainer.swift
//  ZeroVault
//
//  In-memory modal viewer. Decrypts ciphertext in RAM and securely wipes
//  all buffers the instant the view is dismissed.
//

import SwiftUI

public struct SecureFileViewerContainer: View {
    public let file: VaultFile
    @StateObject private var viewerVM: SecureViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingInfoDrawer: Bool = false
    
    public init(file: VaultFile) {
        self.file = file
        _viewerVM = StateObject(wrappedValue: SecureViewerViewModel(file: file))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.06).ignoresSafeArea()
                
                if viewerVM.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                            .scaleEffect(1.4)
                        Text("Decrypting in RAM (AES-256-GCM)...")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                } else if let error = viewerVM.errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Decryption Error")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    // Content Router
                    Group {
                        if file.isPhoto, let image = viewerVM.decryptedImage {
                            SecureImageViewer(image: image)
                        } else if file.isPDF, let pdf = viewerVM.pdfDocument {
                            SecurePDFViewer(document: pdf)
                        } else if file.isText, let text = viewerVM.decryptedText {
                            SecureTextViewer(text: text)
                        } else {
                            // Binary/generic file payload
                            genericPayloadView
                        }
                    }
                }
            }
            .navigationTitle(file.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewerVM.purgeFromMemory()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { showingInfoDrawer.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showingInfoDrawer) {
                fileInfoDrawer
            }
            .onDisappear {
                viewerVM.purgeFromMemory()
            }
        }
    }
    
    // MARK: - Generic Payload View
    
    private var genericPayloadView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: file.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(file.iconColor)
            }
            
            VStack(spacing: 6) {
                Text(file.originalFilename)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(file.formattedSize)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 8) {
                SecurityBadge(title: "AES-256-GCM SEALED")
                SecurityBadge(title: "RAM BUFFER", color: Color(red: 0.4, green: 0.7, blue: 1.0))
            }
            
            Text("This file is decrypted and held securely in memory buffer. It will be completely purged from RAM when closed.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - File Info Sheet
    
    private var fileInfoDrawer: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.09).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    List {
                        Section("METADATA DETAILS") {
                            LabeledContent("Original Name", value: file.originalFilename)
                            LabeledContent("Size", value: file.formattedSize)
                            LabeledContent("MIME Type", value: file.mimeType)
                            LabeledContent("Import Date", value: file.formattedDate)
                            LabeledContent("Vault UUID", value: file.id.uuidString)
                        }
                        
                        Section("CRYPTOGRAPHIC PROOFS") {
                            LabeledContent("Cipher", value: "AES-256-GCM")
                            LabeledContent("iCloud Backup", value: "Excluded (true)")
                            LabeledContent("Files App Sharing", value: "Disabled (false)")
                            LabeledContent("Disk File Name", value: file.diskFilename)
                        }
                        
                        if let notes = file.userNotes, !notes.isEmpty {
                            Section("ATTACHED NOTES") {
                                Text(notes)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("File Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingInfoDrawer = false }
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                }
            }
        }
    }
}
