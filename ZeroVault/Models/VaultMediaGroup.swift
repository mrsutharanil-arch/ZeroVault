//
//  VaultMediaGroup.swift
//  ZeroVault
//
//  Represents a cluster of encrypted files grouped by date or category
//  for organized browsing and high-speed timeline scrubbing.
//

import Foundation

public struct VaultMediaGroup: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public var files: [VaultFile]
    
    public init(id: String, title: String, subtitle: String = "", files: [VaultFile]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.files = files
    }
}
