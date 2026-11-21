//
//  VaultSecuritySettings.swift
//  ZeroVault
//
//  Settings and security policies controlling owner authentication,
//  anti-snooping, and zero-backup enforcement.
//

import Foundation

public enum AutoLockTimeout: Int, CaseIterable, Identifiable, Codable {
    case immediate = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .immediate: return "Immediately on Exit"
        case .thirtySeconds: return "30 Seconds"
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        }
    }
}

public struct VaultSecuritySettings: Codable {
    public var isBiometricsEnabled: Bool = true
    public var autoLockTimeout: AutoLockTimeout = .immediate
    public var isScrambleKeypadEnabled: Bool = true
    public var isAntiScreenshotEnabled: Bool = true
    public var isDecoyVaultEnabled: Bool = false
    public var maxFailedAttempts: Int = 5
    public var autoWipeOnLockout: Bool = true
    
    public init() {}
}
