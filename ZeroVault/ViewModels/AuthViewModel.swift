//
//  AuthViewModel.swift
//  ZeroVault
//
//  ViewModel handling the Owner-Only lock screen, biometric triggers,
//  scrambled keypad generation, and brute-force mitigation.
//

import SwiftUI
import LocalAuthentication
import Combine

public final class AuthViewModel: ObservableObject {
    @Published public var pinInput: String = ""
    @Published public var pinLength: Int = 6
    @Published public var keypadDigits: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
    @Published public var isScrambleEnabled: Bool = true
    
    @Published public var isSettingUpPin: Bool = false
    @Published public var setupStep: Int = 1 // 1: Enter new PIN, 2: Confirm PIN
    @Published public var setupFirstPin: String = ""
    
    @Published public var errorMessage: String? = nil
    @Published public var remainingAttempts: Int = 5
    @Published public var isLockedOut: Bool = false
    @Published public var lockoutSecondsRemaining: Int = 0
    @Published public var isShaking: Bool = false
    
    private let authService = AuthenticationService.shared
    private let keychain = KeychainService.shared
    private var lockoutTimer: AnyCancellable?
    
    public var onAuthSuccess: ((Bool) -> Void)? // Parameter: isDecoyMode
    
    public init() {
        checkInitialSetup()
        shuffleKeypadIfNeeded()
    }
    
    public func checkInitialSetup() {
        // If no PIN has ever been set, we enter setup mode
        let hasPin = keychain.retrievePinHash() != nil
        self.isSettingUpPin = !hasPin
    }
    
    public func shuffleKeypadIfNeeded() {
        if isScrambleEnabled {
            // Shuffle digits 0..9
            keypadDigits = (0...9).shuffled()
        } else {
            keypadDigits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        }
    }
    
    // MARK: - Keypad Interactions
    
    public func appendDigit(_ digit: Int) {
        guard pinInput.count < pinLength else { return }
        pinInput.append("\(digit)")
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if pinInput.count == pinLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.processPinEntry()
            }
        }
    }
    
    public func deleteDigit() {
        guard !pinInput.isEmpty else { return }
        pinInput.removeLast()
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    public func clearPin() {
        pinInput = ""
    }
    
    // MARK: - Process PIN Verification
    
    private func processPinEntry() {
        if isSettingUpPin {
            handlePinSetupStep()
            return
        }
        
        let result = authService.authenticateWithPin(pinInput)
        switch result {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            pinInput = ""
            errorMessage = nil
            onAuthSuccess?(false)
            
        case .decoySuccess:
            // Coerced duress entry -> open decoy vault
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            pinInput = ""
            errorMessage = nil
            onAuthSuccess?(true)
            
        case .incorrectPin(let remaining):
            triggerFailedAttempt(remainingAttempts: remaining, message: "Incorrect PIN. \(remaining) attempts remaining.")
            
        case .lockedOut(let seconds):
            startLockoutTimer(seconds: seconds)
            
        case .selfDestructTriggered:
            errorMessage = "Self-destruct triggered: Maximum failed attempts reached. All encryption keys destroyed."
            pinInput = ""
            
        case .biometricsUnavailable:
            break
        }
    }
    
    // MARK: - First-Time Setup Flow
    
    private func handlePinSetupStep() {
        if setupStep == 1 {
            setupFirstPin = pinInput
            pinInput = ""
            setupStep = 2
            errorMessage = nil
            shuffleKeypadIfNeeded()
        } else if setupStep == 2 {
            if pinInput == setupFirstPin {
                do {
                    try authService.setupOwnerPin(pinInput)
                    // Optional default decoy PIN
                    try? authService.setupDecoyPin("000000")
                    isSettingUpPin = false
                    pinInput = ""
                    errorMessage = nil
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onAuthSuccess?(false)
                } catch {
                    errorMessage = "Failed to store owner key: \(error.localizedDescription)"
                }
            } else {
                setupStep = 1
                setupFirstPin = ""
                pinInput = ""
                errorMessage = "PINs did not match. Please enter your new PIN again."
                triggerShake()
            }
        }
    }
    
    // MARK: - Biometric Face ID Trigger
    
    public func triggerFaceID() {
        guard !isSettingUpPin else { return }
        Task {
            let result = await authService.authenticateWithBiometrics()
            await MainActor.run {
                switch result {
                case .success:
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    self.onAuthSuccess?(false)
                case .biometricsUnavailable(let msg):
                    self.errorMessage = msg
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Failed Attempt & Lockout
    
    private func triggerFailedAttempt(remainingAttempts: Int, message: String) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        self.remainingAttempts = remainingAttempts
        self.errorMessage = message
        self.pinInput = ""
        triggerShake()
        shuffleKeypadIfNeeded()
    }
    
    private func triggerShake() {
        isShaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isShaking = false
        }
    }
    
    private func startLockoutTimer(seconds: Int) {
        isLockedOut = true
        lockoutSecondsRemaining = seconds
        pinInput = ""
        errorMessage = "Vault is locked out for protection. Try again in \(seconds)s."
        
        lockoutTimer?.cancel()
        lockoutTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.lockoutSecondsRemaining > 0 {
                    self.lockoutSecondsRemaining -= 1
                    self.errorMessage = "Vault is locked out for protection. Try again in \(self.lockoutSecondsRemaining)s."
                } else {
                    self.isLockedOut = false
                    self.errorMessage = nil
                    self.lockoutTimer?.cancel()
                }
            }
    }
}
