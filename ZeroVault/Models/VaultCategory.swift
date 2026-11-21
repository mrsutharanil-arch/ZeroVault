//
//  VaultCategory.swift
//  ZeroVault
//
//  Created for Sovereign Owner-Only Secure Storage.
//

import SwiftUI

public enum VaultCategory: String, CaseIterable, Codable, Identifiable {
    case all = "All Files"
    case photos = "Photos"
    case videos = "Videos"
    case documents = "Documents"
    case notes = "Secret Notes"
    case audio = "Voice Memos"
    case archives = "Archives"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "shield.fill"
        case .photos: return "photo.fill"
        case .videos: return "video.fill"
        case .documents: return "doc.text.fill"
        case .notes: return "lock.doc.fill"
        case .audio: return "mic.fill"
        case .archives: return "archivebox.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .all: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case .photos: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .videos: return Color(red: 1.0, green: 0.4, blue: 0.5)
        case .documents: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .notes: return Color(red: 0.8, green: 0.5, blue: 1.0)
        case .audio: return Color(red: 0.3, green: 0.9, blue: 0.9)
        case .archives: return Color(red: 0.7, green: 0.7, blue: 0.8)
        }
    }
}
