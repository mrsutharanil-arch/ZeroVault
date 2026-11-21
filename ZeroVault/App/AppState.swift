//
//  AppState.swift
//  ZeroVault
//
//  Global application security state, handling immediate auto-lock,
//  privacy curtain in app switcher, and screen capture prevention.
//

import SwiftUI
import Combine

public final class AppState: ObservableObject {
    @Published public var isUnlocked: Bool = false
    @Published public var isDecoyMode: Bool = false
    @Published public var isPrivacyCurtainActive: Bool = false
    @Published public var isScreenCaptured: Bool = false
    
    @Published public var settings: VaultSecuritySettings = VaultSecuritySettings()
    
    private var backgroundTimestamp: Date? = nil
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupScreenCaptureNotification()
    }
    
    // MARK: - ScenePhase Lifecycle Handlers
    
    public func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .inactive:
            // Entering multitasking app switcher: immediately obscure view
            isPrivacyCurtainActive = true
            
        case .background:
            // App sent to background
            isPrivacyCurtainActive = true
            backgroundTimestamp = Date()
            
            if settings.autoLockTimeout == .immediate {
                lockVault()
            }
            
        case .active:
            // Returning to foreground
            if let timestamp = backgroundTimestamp {
                let elapsed = Date().timeIntervalSince(timestamp)
                if elapsed >= Double(settings.autoLockTimeout.rawValue) {
                    lockVault()
                }
            }
            backgroundTimestamp = nil
            
            // Only dismiss privacy curtain if user is authenticated
            if isUnlocked {
                isPrivacyCurtainActive = false
            }
            
        @unknown default:
            break
        }
    }
    
    public func lockVault() {
        isUnlocked = false
        isDecoyMode = false
        isPrivacyCurtainActive = false
    }
    
    public func unlockVault(isDecoy: Bool = false) {
        self.isUnlocked = true
        self.isDecoyMode = isDecoy
        self.isPrivacyCurtainActive = false
    }
    
    // MARK: - Anti-Screen Recording Observer
    
    private func setupScreenCaptureNotification() {
        NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    let isCaptured = UIScreen.main.isCaptured
                    self?.isScreenCaptured = isCaptured
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Latest Apple iOS SF Pro Typography & Front Design System

public enum ZeroVaultFont {
    /// SF Pro Rounded - Brand Hero Headers & Prominent Titles
    public static func heroTitle() -> Font {
        .system(size: 26, weight: .heavy, design: .rounded)
    }
    
    /// SF Pro Rounded - Large Storage Metric Numbers
    public static func metricNumber() -> Font {
        .system(size: 30, weight: .black, design: .rounded)
    }
    
    /// SF Pro Rounded - PIN Keypad Digits
    public static func keypadDigit() -> Font {
        .system(size: 28, weight: .medium, design: .rounded)
    }
    
    /// SF Pro Rounded - Action Buttons, Badges, Category Chips
    public static func actionButton() -> Font {
        .system(size: 15, weight: .bold, design: .rounded)
    }
    
    /// SF Pro Rounded - Group Headers
    public static func groupTitle() -> Font {
        .system(size: 15, weight: .heavy, design: .rounded)
    }
    
    /// SF Mono - Cryptographic nonces, SHA-256 tags & forensic audit indicators
    public static func cryptoAudit() -> Font {
        .system(size: 11, weight: .black, design: .monospaced)
    }
    
    /// SF Mono - File sizes, nonces, timestamps & counters
    public static func monoMeta() -> Font {
        .system(size: 10, weight: .bold, design: .monospaced)
    }
    
    /// SF Pro Default - Standard body text
    public static func bodyText() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }
}
