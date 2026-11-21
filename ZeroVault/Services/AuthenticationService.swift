//
//  AuthenticationService.swift
//  ZeroVault
//
//  Handles Owner-Only authentication via Face ID / Touch ID biometrics,
//  secure PIN verification, duress/decoy PIN detection, and anti-tamper lockouts.
//

import Foundation
import LocalAuthentication
import CryptoKit

public enum AuthResult {
    case success
    case decoySuccess
    case incorrectPin(remainingAttempts: Int)
    case lockedOut(lockoutDurationSeconds: Int)
    case selfDestructTriggered
    case biometricsUnavailable(String)
}

public final class AuthenticationService: ObservableObject {
    public static let shared = AuthenticationService()
    
    private let keychain = KeychainService.shared
    private let storage = StorageSecurityService.shared
    
    @Published public private(set) var isBiometricsAvailable: Bool = false
    @Published public private(set) var biometricType: LABiometryType = .none
    @Published public private(set) var failedAttempts: Int = 0
    @Published public private(set) var lockoutEndTime: Date?
    
    private let maxAllowedAttempts: Int = 5
    
    private init() {
        checkBiometricAvailability()
    }
    
    // MARK: - Biometric Support Check
    
    public func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        DispatchQueue.main.async {
            self.isBiometricsAvailable = canEvaluate
            self.biometricType = context.biometryType
        }
    }
    
    public var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }
    
    // MARK: - Biometric Authentication (Owner Face ID)
    
    public func authenticateWithBiometrics(reason: String = "Authenticate to unlock your ZeroVault") async -> AuthResult {
        guard isBiometricsAvailable else {
            return .biometricsUnavailable("Biometric authentication is not configured on this device.")
        }
        
        if isLockedOut {
            return .lockedOut(lockoutDurationSeconds: remainingLockoutSeconds)
        }
        
        let context = LAContext()
        context.localizedCancelTitle = "Use PIN"
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if success {
                        self.failedAttempts = 0
                        self.lockoutEndTime = nil
                        continuation.resume(returning: .success)
                    } else {
                        let errorMsg = error?.localizedDescription ?? "Face ID match failed"
                        continuation.resume(returning: .biometricsUnavailable(errorMsg))
                    }
                }
            }
        }
    }
    
    // MARK: - PIN Authentication
    
    public func authenticateWithPin(_ pin: String) -> AuthResult {
        if isLockedOut {
            return .lockedOut(lockoutDurationSeconds: remainingLockoutSeconds)
        }
        
        // Check for Decoy PIN (Duress Mode)
        if let decoyHash = keychain.retrieveDecoyPinHash(), !decoyHash.isEmpty {
            let candidateDecoyHash = hashPin(pin, salt: Data("ZeroVault.DecoySalt".utf8))
            if candidateDecoyHash == decoyHash {
                // Decoy mode entered! Reset lockout, show fake clean vault
                return .decoySuccess
            }
        }
        
        // Check Master Owner PIN
        guard let storedHash = keychain.retrievePinHash(),
              let salt = keychain.retrievePinSalt() else {
            // First time setup - will be handled by setup flow
            return .incorrectPin(remainingAttempts: 0)
        }
        
        let candidateHash = hashPin(pin, salt: salt)
        if candidateHash == storedHash {
            // Success! Reset failed attempts
            failedAttempts = 0
            lockoutEndTime = nil
            return .success
        } else {
            // Failed attempt
            failedAttempts += 1
            let remaining = maxAllowedAttempts - failedAttempts
            
            if remaining <= 0 {
                // Trigger Self-Destruct or Lockout
                triggerLockout()
                if failedAttempts >= 10 {
                    triggerSelfDestruct()
                    return .selfDestructTriggered
                }
                return .lockedOut(lockoutDurationSeconds: remainingLockoutSeconds)
            }
            return .incorrectPin(remainingAttempts: remaining)
        }
    }
    
    // MARK: - Lockout & Anti-Brute-Force
    
    public var isLockedOut: Bool {
        guard let end = lockoutEndTime else { return false }
        return Date() < end
    }
    
    public var remainingLockoutSeconds: Int {
        guard let end = lockoutEndTime else { return 0 }
        let diff = Int(end.timeIntervalSince(Date()))
        return max(0, diff)
    }
    
    private func triggerLockout() {
        // 60-second penalty lockout for 5 attempts, escalating
        let penaltySeconds = min(300, 60 * (failedAttempts - maxAllowedAttempts + 1))
        lockoutEndTime = Date().addingTimeInterval(TimeInterval(penaltySeconds))
    }
    
    public func triggerSelfDestruct() {
        // Complete panic wipe: destroy all keys and shred files
        keychain.wipeAllKeys()
        storage.wipeAllStorage()
        failedAttempts = 0
        lockoutEndTime = nil
    }
    
    // MARK: - Initial Setup & Change PIN
    
    public func setupOwnerPin(_ pin: String) throws {
        let salt = CryptographyService.shared.generateRandomSalt(count: 32)
        let hash = hashPin(pin, salt: salt)
        try keychain.savePinHash(hash, salt: salt)
        
        // If master key doesn't exist yet, generate and save it
        if !keychain.hasMasterKey {
            let masterKey = CryptographyService.shared.generateMasterKey()
            try keychain.saveMasterKey(masterKey)
        }
    }
    
    public func changeOwnerPin(currentPin: String, newPin: String) throws -> Bool {
        guard let storedHash = keychain.retrievePinHash(),
              let salt = keychain.retrievePinSalt() else {
            return false
        }
        
        let candidateHash = hashPin(currentPin, salt: salt)
        guard candidateHash == storedHash else {
            return false // Old PIN incorrect
        }
        
        // Generate fresh salt and new hash
        let newSalt = CryptographyService.shared.generateRandomSalt(count: 32)
        let newHash = hashPin(newPin, salt: newSalt)
        try keychain.savePinHash(newHash, salt: newSalt)
        return true
    }
    
    public func setupDecoyPin(_ pin: String) throws {
        let hash = hashPin(pin, salt: Data("ZeroVault.DecoySalt".utf8))
        try keychain.saveDecoyPinHash(hash)
    }
    
    // MARK: - Hashing Helper
    
    private func hashPin(_ pin: String, salt: Data) -> String {
        var input = Data(pin.utf8)
        input.append(salt)
        let digest = SHA256.hash(data: input)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
