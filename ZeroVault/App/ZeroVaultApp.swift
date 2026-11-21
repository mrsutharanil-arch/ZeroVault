//
//  ZeroVaultApp.swift
//  ZeroVault
//
//  Sovereign Owner-Only Encrypted File Vault Application Entry Point.
//  Strictly enforces immediate auto-lock, no backup, sandbox isolation,
//  and privacy shield in the iOS App Switcher.
//

import SwiftUI

@main
struct ZeroVaultApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var vaultVM = VaultViewModel()
    @StateObject private var authVM = AuthViewModel()
    
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Enforce storage isolation directory and no-backup flags upon boot
        StorageSecurityService.shared.createSecureVaultDirectoryIfNeeded()
        // Ensure master encryption key & default sovereign credentials exist
        AuthenticationService.shared.ensureInitialMasterSecurity()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main Content
                if appState.isUnlocked {
                    VaultHomeView(vaultVM: vaultVM, appState: appState)
                        .transition(.opacity)
                } else {
                    LockScreenView(authVM: authVM)
                        .transition(.opacity)
                }
                
                // Privacy Curtain / Anti-Shoulder Surfing / Screen Recording Shield
                if appState.isPrivacyCurtainActive || appState.isScreenCaptured {
                    SecureOverlayShield(isRecording: appState.isScreenCaptured)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                setupAuthCallbacks()
            }
            .onChange(of: scenePhase) { newPhase in
                appState.handleScenePhaseChange(to: newPhase)
                if newPhase == .active && !appState.isUnlocked {
                    authVM.shuffleKeypadIfNeeded()
                }
            }
        }
    }
    
    private func setupAuthCallbacks() {
        authVM.onAuthSuccess = { isDecoy in
            withAnimation(.easeInOut(duration: 0.25)) {
                vaultVM.isDecoyMode = isDecoy
                appState.unlockVault(isDecoy: isDecoy)
                vaultVM.loadVaultFiles()
            }
        }
    }
}
