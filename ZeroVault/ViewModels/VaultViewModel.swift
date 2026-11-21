//
//  VaultViewModel.swift
//  ZeroVault
//
//  ViewModel orchestrating encrypted vault operations:
//  - Loading encrypted items into RAM
//  - Live filtering, sorting, and search
//  - Importing photos, documents, and secure notes
//  - Secure multi-pass file shredding
//  - Storage audit metrics
//

import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

public final class VaultViewModel: ObservableObject {
    @Published public var files: [VaultFile] = []
    @Published public var selectedCategory: VaultCategory = .all
    @Published public var searchQuery: String = ""
    @Published public var isImportingDocument: Bool = false
    @Published public var isImportingPhoto: Bool = false
    @Published public var isShowingCamera: Bool = false
    @Published public var isCreatingNote: Bool = false
    @Published public var isShowingAuditSheet: Bool = false
    @Published public var isShowingSettings: Bool = false
    @Published public var activeViewerFile: VaultFile? = nil
    
    @Published public var totalStorageBytes: Int64 = 0
    @Published public var totalFileCount: Int = 0
    @Published public var isDecoyMode: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let crypto = CryptographyService.shared
    private let storage = StorageSecurityService.shared
    private let keychain = KeychainService.shared
    
    public init() {
        loadVaultFiles()
    }
    
    // MARK: - Filtered Files
    
    public var filteredFiles: [VaultFile] {
        files.filter { file in
            let matchesCategory = (selectedCategory == .all) || (file.category == selectedCategory)
            let matchesSearch = searchQuery.isEmpty ||
                file.title.localizedCaseInsensitiveContains(searchQuery) ||
                file.originalFilename.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    
    public var formattedStorageString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalStorageBytes)
    }
    
    // MARK: - Load Encrypted Vault Files
    
    public func loadVaultFiles() {
        if isDecoyMode {
            // Decoy mode: show empty vault, or 1 harmless file
            self.files = []
            self.totalStorageBytes = 0
            self.totalFileCount = 0
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let masterKey = try? keychain.retrieveMasterKey() else {
            self.files = []
            return
        }
        
        let dir = storage.vaultDirectoryURL
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else {
            self.files = []
            return
        }
        
        var loadedFiles: [VaultFile] = []
        var totalBytes: Int64 = 0
        
        for url in fileURLs {
            let filename = url.lastPathComponent
            // Ignore system files or index files
            if filename.hasPrefix(".") || !filename.hasSuffix(".zenc") {
                continue
            }
            
            do {
                let encryptedData = try Data(contentsOf: url)
                totalBytes += Int64(encryptedData.count)
                
                // Fast header-only decryption of metadata
                let metadata = try crypto.decryptMetadataOnly(from: encryptedData, using: masterKey)
                
                let vaultFile = VaultFile(
                    id: metadata.id,
                    diskFilename: filename,
                    title: metadata.title,
                    originalFilename: metadata.originalFilename,
                    mimeType: metadata.mimeType,
                    category: metadata.category,
                    fileSize: metadata.fileSize,
                    createdAt: metadata.createdAt,
                    isFavorite: false,
                    userNotes: metadata.userNotes
                )
                loadedFiles.append(vaultFile)
            } catch {
                print("Could not read vault file \(filename): \(error)")
            }
        }
        
        self.files = loadedFiles
        self.totalStorageBytes = totalBytes
        self.totalFileCount = loadedFiles.count
    }
    
    // MARK: - Encrypt & Import File (General)
    
    public func importRawData(
        data: Data,
        originalFilename: String,
        category: VaultCategory,
        title: String? = nil,
        userNotes: String? = nil
    ) throws {
        guard let masterKey = try keychain.retrieveMasterKey() else {
            throw VaultCryptoError.keyDerivationFailed
        }
        
        let id = UUID()
        let diskFilename = "\(id.uuidString).zenc"
        let displayTitle = (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? title!
            : (originalFilename as NSString).deletingPathExtension
        
        let mimeType = mimeTypeFor(filename: originalFilename)
        let checksum = crypto.computeSha256(data: data)
        
        let metadata = EncryptedFileMetadata(
            id: id,
            originalFilename: originalFilename,
            title: displayTitle,
            mimeType: mimeType,
            category: category,
            fileSize: Int64(data.count),
            checksumSha256: checksum,
            userNotes: userNotes
        )
        
        // Encrypt with AES-256-GCM
        let encryptedPackage = try crypto.encrypt(
            payload: data,
            metadata: metadata,
            using: masterKey
        )
        
        // Persist to isolated Application Support container with complete file protection & no backup
        _ = try storage.saveEncryptedPayload(encryptedPackage, filename: diskFilename)
        
        // Refresh state
        loadVaultFiles()
    }
    
    // MARK: - Direct Camera Photo Import
    
    public func importCameraPhoto(data: Data) throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "SecurePhoto_\(timestamp).jpg"
        try importRawData(
            data: data,
            originalFilename: filename,
            category: .photos,
            title: "Encrypted Photo \(timestamp)",
            userNotes: "Captured directly to RAM via ZeroVault secure camera."
        )
    }
    
    // MARK: - Secret Note Creation
    
    public func createSecretNote(title: String, content: String) throws {
        guard let data = content.data(using: .utf8) else { return }
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "Note_\(timestamp).txt"
        try importRawData(
            data: data,
            originalFilename: filename,
            category: .notes,
            title: title.isEmpty ? "Encrypted Note \(timestamp)" : title,
            userNotes: "Encrypted note created directly in ZeroVault."
        )
    }
    
    // MARK: - Secure File Deletion (Multi-Pass Shred)
    
    public func deleteFile(_ file: VaultFile) {
        do {
            try storage.shredFile(filename: file.diskFilename)
            files.removeAll { $0.id == file.id }
            totalStorageBytes -= file.fileSize
            totalFileCount = files.count
        } catch {
            errorMessage = "Failed to shred file: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Panic Wipe All
    
    public func purgeAllFiles() {
        storage.wipeAllStorage()
        files.removeAll()
        totalStorageBytes = 0
        totalFileCount = 0
    }
    
    // MARK: - Helpers
    
    private func mimeTypeFor(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "pdf": return "application/pdf"
        case "txt", "md": return "text/plain"
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}
