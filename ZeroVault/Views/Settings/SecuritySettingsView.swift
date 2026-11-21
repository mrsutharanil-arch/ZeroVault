//
//  SecuritySettingsView.swift
//  ZeroVault
//
//  Owner security controls: Face ID toggles, auto-lock policies,
//  scrambled keypad settings, decoy PIN, and emergency self-destruct.
//

import SwiftUI

public struct SecuritySettingsView: View {
    @ObservedObject public var appState: AppState
    @ObservedObject public var vaultVM: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingChangePin: Bool = false
    @State private var showingDecoySetup: Bool = false
    @State private var showingPanicConfirm: Bool = false
    @State private var showingDeveloperProfile: Bool = false
    @State private var decoyPinInput: String = ""
    
    public init(appState: AppState, vaultVM: VaultViewModel) {
        self.appState = appState
        self.vaultVM = vaultVM
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.07).ignoresSafeArea()
                
                List {
                    // MARK: - Section 1: Authentication & Access
                    Section(header: Text("OWNER ACCESS CONTROL").foregroundColor(.gray)) {
                        Toggle(isOn: $appState.settings.isBiometricsEnabled) {
                            HStack {
                                Image(systemName: "faceid")
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                                Text("Face ID / Touch ID")
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Picker(selection: $appState.settings.autoLockTimeout) {
                            ForEach(AutoLockTimeout.allCases) { timeout in
                                Text(timeout.title).tag(timeout)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                Text("Auto-Lock When Leaving")
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Toggle(isOn: $appState.settings.isScrambleKeypadEnabled) {
                            HStack {
                                Image(systemName: "shuffle")
                                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scramble Keypad Layout")
                                        .foregroundColor(.white)
                                    Text("Randomizes 0-9 digits to prevent smudge attacks and shoulder surfing.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.09))
                    
                    // MARK: - Section 2: Duress & Decoy Vault
                    Section(header: Text("DURESS & COERCION PROTECTION").foregroundColor(.gray)) {
                        Toggle(isOn: $appState.settings.isDecoyVaultEnabled) {
                            HStack {
                                Image(systemName: "theatermasks.fill")
                                    .foregroundColor(Color(red: 0.8, green: 0.5, blue: 1.0))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Stealth Decoy Vault")
                                        .foregroundColor(.white)
                                    Text("Entering an alternate decoy PIN opens an innocent empty vault under duress.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        if appState.settings.isDecoyVaultEnabled {
                            Button(action: { showingDecoySetup = true }) {
                                HStack {
                                    Text("Configure Decoy PIN")
                                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.09))
                    
                    // MARK: - Section 3: Anti-Tamper & Self-Destruct
                    Section(header: Text("BRUTE-FORCE & SELF-DESTRUCT").foregroundColor(.gray)) {
                        Toggle(isOn: $appState.settings.autoWipeOnLockout) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Emergency Self-Destruct")
                                        .foregroundColor(.white)
                                    Text("Erase all cryptographic keys permanently if 10 consecutive wrong PINs are entered.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.09))
                    
                    // MARK: - Section 4: Emergency Manual Wipe
                    Section(header: Text("PANIC ACTIONS").foregroundColor(.gray)) {
                        Button(action: {
                            showingPanicConfirm = true
                        }) {
                            HStack {
                                Image(systemName: "trash.slash.fill")
                                    .foregroundColor(.red)
                                Text("Purge Vault & Wipe Keys Now")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.09))
                    
                    // MARK: - Section 5: Company & Developer Profile
                    Section(header: Text("DEVELOPER & COMPANY PROFILE").foregroundColor(.gray)) {
                        Button(action: { showingDeveloperProfile = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "person.badge.shield.checkmark.fill")
                                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Arch Technologies")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Lead Architect: Anil Suthar (@mrsutharanil-arch)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.09))
                    
                    // MARK: - Section 6: Architecture Info
                    Section(header: Text("ZERO-KNOWLEDGE ARCHITECTURE").foregroundColor(.gray)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ZeroVault 1.0.0 (Build 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("100% Offline • Air-Gapped • No Network Calls • Hardware AES-256-GCM • Secure Enclave Key Anchoring • Strict No-Backup Policy")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineSpacing(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(white: 0.09))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Security Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                }
            }
            .alert(isPresented: $showingPanicConfirm) {
                Alert(
                    title: Text("CRITICAL WARNING: Self-Destruct"),
                    message: Text("This will immediately overwrite and shred all encrypted files and eliminate the master encryption key from the Secure Enclave. This action is irreversible."),
                    primaryButton: .destructive(Text("Destroy Everything")) {
                        AuthenticationService.shared.triggerSelfDestruct()
                        appState.lockVault()
                        vaultVM.purgeAllFiles()
                        dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingDeveloperProfile) {
                DeveloperProfileView()
            }
            .sheet(isPresented: $showingDecoySetup) {
                NavigationStack {
                    ZStack {
                        Color(red: 0.05, green: 0.07, blue: 0.09).ignoresSafeArea()
                        VStack(spacing: 20) {
                            Text("Enter 6-digit Decoy PIN")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            SecureField("6-digit PIN", text: $decoyPinInput)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .background(Color(white: 0.12))
                                .cornerRadius(10)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .padding(.top, 40)
                    }
                    .navigationTitle("Decoy PIN Setup")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingDecoySetup = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if decoyPinInput.count == 6 {
                                    try? AuthenticationService.shared.setupDecoyPin(decoyPinInput)
                                    showingDecoySetup = false
                                }
                            }
                            .disabled(decoyPinInput.count != 6)
                        }
                    }
                }
            }
        }
    }
}
