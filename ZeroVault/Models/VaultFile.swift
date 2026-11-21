//
//  VaultFile.swift
//  ZeroVault
//
//  Model representing an encrypted file item within the ZeroVault file fortress.
//

import Foundation
import SwiftUI

public struct VaultFile: Identifiable, Codable, Hashable {
    public let id: UUID
    public let diskFilename: String // Stored as random UUID on disk: e.g. "81B578F4...zenc"
    public var title: String
    public let originalFilename: String
    public let mimeType: String
    public var category: VaultCategory
    public let fileSize: Int64
    public let createdAt: Date
    public var isFavorite: Bool
    public var userNotes: String?
    
    public init(
        id: UUID = UUID(),
        diskFilename: String? = nil,
        title: String,
        originalFilename: String,
        mimeType: String,
        category: VaultCategory,
        fileSize: Int64,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        userNotes: String? = nil
    ) {
        self.id = id
        self.diskFilename = diskFilename ?? "\(id.uuidString).zenc"
        self.title = title
        self.originalFilename = originalFilename
        self.mimeType = mimeType
        self.category = category
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.userNotes = userNotes
    }
    
    // MARK: - Formatters & Helpers
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    public var isPhoto: Bool {
        mimeType.starts(with: "image/") ||
        ["jpg", "jpeg", "png", "heic", "webp", "gif"].contains(fileExtension.lowercased())
    }
    
    public var isVideo: Bool {
        mimeType.starts(with: "video/") ||
        ["mp4", "mov", "m4v", "avi", "mkv"].contains(fileExtension.lowercased())
    }
    
    public var isPDF: Bool {
        mimeType == "application/pdf" || fileExtension.lowercased() == "pdf"
    }
    
    public var isAudio: Bool {
        mimeType.starts(with: "audio/") ||
        ["m4a", "mp3", "wav", "aac"].contains(fileExtension.lowercased())
    }
    
    public var isText: Bool {
        mimeType.starts(with: "text/") ||
        category == .notes ||
        ["txt", "md", "json", "swift", "csv", "log"].contains(fileExtension.lowercased())
    }
    
    public var fileExtension: String {
        (originalFilename as NSString).pathExtension
    }
    
    public var iconName: String {
        if isPhoto { return "photo.fill" }
        if isVideo { return "play.rectangle.fill" }
        if isPDF { return "doc.richtext.fill" }
        if isAudio { return "waveform" }
        if isText { return "doc.text.fill" }
        return "shield.fill"
    }
    
    public var iconColor: Color {
        if isPhoto { return Color(red: 0.35, green: 0.65, blue: 1.0) }
        if isVideo { return Color(red: 1.0, green: 0.35, blue: 0.45) }
        if isPDF { return Color(red: 1.0, green: 0.4, blue: 0.3) }
        if isAudio { return Color(red: 0.3, green: 0.85, blue: 0.75) }
        if isText { return Color(red: 0.75, green: 0.5, blue: 1.0) }
        return Color(red: 0.2, green: 0.8, blue: 0.6)
    }
}
