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

public enum ViewLayoutMode: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"
    public var id: String { rawValue }
}

public enum GroupingOption: String, CaseIterable, Identifiable {
    case date = "Date"
    case type = "Type"
    case none = "None"
    public var id: String { rawValue }
}

public final class VaultViewModel: ObservableObject {
    @Published public var files: [VaultFile] = []
    @Published public var selectedCategory: VaultCategory = .all
    @Published public var searchQuery: String = ""
    @Published public var layoutMode: ViewLayoutMode = .grid
    @Published public var groupingOption: GroupingOption = .date
    
    @Published public var isImportingDocument: Bool = false
    @Published public var isImportingPhoto: Bool = false
    @Published public var isShowingCamera: Bool = false
    @Published public var isCreatingNote: Bool = false
    @Published public var isShowingAuditSheet: Bool = false
    @Published public var isShowingSettings: Bool = false
    @Published public var activeViewerFile: VaultFile? = nil
    
    // Media gallery swiper
    @Published public var isPresentingGallery: Bool = false
    @Published public var activeGalleryFiles: [VaultFile] = []
    @Published public var activeGalleryIndex: Int = 0
    
    @Published public var totalStorageBytes: Int64 = 0
    @Published public var totalFileCount: Int = 0
    @Published public var isDecoyMode: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    public var formattedStorageString: String {
        ByteCountFormatter.string(fromByteCount: totalStorageBytes, countStyle: .file)
    }
    
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
    
    // MARK: - Grouped Media & Files for Fast Scrolling
    
    public var groupedFiles: [VaultMediaGroup] {
        let items = filteredFiles
        guard !items.isEmpty else { return [] }
        
        switch groupingOption {
        case .none:
            let totalBytes = items.reduce(0) { $0 + $1.fileSize }
            let sizeStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return [VaultMediaGroup(id: "all", title: "All Encrypted Files", subtitle: "\(items.count) items • \(sizeStr)", files: items)]
            
        case .type:
            var dict: [String: [VaultFile]] = [:]
            var order: [String] = []
            for file in items {
                let catName = file.category.rawValue
                if dict[catName] == nil {
                    dict[catName] = []
                    order.append(catName)
                }
                dict[catName]?.append(file)
            }
            return order.map { key in
                let groupFiles = dict[key] ?? []
                let totalBytes = groupFiles.reduce(0) { $0 + $1.fileSize }
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                return VaultMediaGroup(id: key, title: key, subtitle: "\(groupFiles.count) items • \(sizeStr)", files: groupFiles)
            }
            
        case .date:
            let calendar = Calendar.current
            var dict: [String: [VaultFile]] = [:]
            var order: [String] = []
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            
            for file in items {
                let sectionTitle: String
                if calendar.isDateInToday(file.createdAt) {
                    sectionTitle = "Today"
                } else if calendar.isDateInYesterday(file.createdAt) {
                    sectionTitle = "Yesterday"
                } else if let daysAgo = calendar.dateComponents([.day], from: file.createdAt, to: Date()).day, daysAgo < 7 {
                    sectionTitle = "This Week"
                } else {
                    sectionTitle = dateFormatter.string(from: file.createdAt)
                }
                
                if dict[sectionTitle] == nil {
                    dict[sectionTitle] = []
                    order.append(sectionTitle)
                }
                dict[sectionTitle]?.append(file)
            }
            
            return order.map { key in
                let groupFiles = dict[key] ?? []
                let totalBytes = groupFiles.reduce(0) { $0 + $1.fileSize }
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                return VaultMediaGroup(id: key, title: key, subtitle: "\(groupFiles.count) items • \(sizeStr)", files: groupFiles)
            }
        }
    }
    
    // MARK: - Open Media Carousel or Single Viewer
    
    public func openFileViewer(_ file: VaultFile) {
        if file.isPhoto || file.isVideo {
            let mediaOnly = filteredFiles.filter { $0.isPhoto || $0.isVideo }
            if let idx = mediaOnly.firstIndex(where: { $0.id == file.id }) {
                self.activeGalleryFiles = mediaOnly
                self.activeGalleryIndex = idx
                self.isPresentingGallery = true
                return
            }
        }
        self.activeViewerFile = file
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
        
        let masterKey = keychain.getOrCreateMasterKey()
        
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
                
                // Infer category if set to .all
                var resolvedCategory = metadata.category
                if resolvedCategory == .all {
                    resolvedCategory = self.inferCategory(for: metadata.originalFilename)
                }
                
                let vaultFile = VaultFile(
                    id: metadata.id,
                    diskFilename: filename,
                    title: metadata.title,
                    originalFilename: metadata.originalFilename,
                    mimeType: metadata.mimeType,
                    category: resolvedCategory,
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
        
        DispatchQueue.main.async {
            self.files = loadedFiles
            self.totalStorageBytes = totalBytes
            self.totalFileCount = loadedFiles.count
        }
    }
    
    // MARK: - Encrypt & Import File (General)
    
    public func importRawData(
        data: Data,
        originalFilename: String,
        category: VaultCategory,
        title: String? = nil,
        userNotes: String? = nil
    ) throws {
        let masterKey = keychain.getOrCreateMasterKey()
        
        let id = UUID()
        let diskFilename = "\(id.uuidString).zenc"
        let displayTitle = (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? title!
            : (originalFilename as NSString).deletingPathExtension
        
        let mimeType = mimeTypeFor(filename: originalFilename)
        let checksum = crypto.computeSha256(data: data)
        
        var resolvedCategory = category
        if resolvedCategory == .all {
            resolvedCategory = inferCategory(for: originalFilename)
        }
        
        let metadata = EncryptedFileMetadata(
            id: id,
            originalFilename: originalFilename,
            title: displayTitle,
            mimeType: mimeType,
            category: resolvedCategory,
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
    
    private func inferCategory(for filename: String) -> VaultCategory {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "webp", "gif", "bmp", "tiff"].contains(ext) {
            return .photos
        } else if ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext) {
            return .videos
        } else if ["pdf", "doc", "docx", "pages", "xls", "xlsx", "numbers", "ppt", "pptx", "key"].contains(ext) {
            return .documents
        } else if ["txt", "md", "json", "csv", "log", "swift", "html"].contains(ext) {
            return .notes
        } else if ["mp3", "m4a", "wav", "aac", "flac", "ogg"].contains(ext) {
            return .audio
        } else if ["zip", "tar", "gz", "rar", "7z"].contains(ext) {
            return .archives
        }
        return .documents
    }
    
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
