//
//  KeychainService.swift
//  ZeroVault
//
//  Hardware-backed Secure Enclave & Keychain storage manager.
//  Binds cryptographic keys strictly to this physical device hardware with
//  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly to prevent iCloud Keychain syncing.
//

import Foundation
import Security
import CryptoKit

public final class KeychainService {
    public static let shared = KeychainService()
    
    private let serviceIdentifier = "com.zerovault.keys"
    private let masterKeyAccount = "ZeroVault.MasterAESKey"
    private let pinHashAccount = "ZeroVault.OwnerPinHash"
    private let pinSaltAccount = "ZeroVault.OwnerPinSalt"
    private let decoyPinAccount = "ZeroVault.DecoyPinHash"
    
    private init() {}
    
    // MARK: - Master AES-256 Key Management
    
    /// Saves the 256-bit AES master key to the hardware-bound iOS Keychain.
    public func saveMasterKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try saveItem(data: keyData, account: masterKeyAccount, accessPolicy: .deviceOnly)
    }
    
    /// Retrieves the master key from Keychain. Returns nil if not configured yet.
    public func retrieveMasterKey() throws -> SymmetricKey? {
        guard let data = try retrieveItem(account: masterKeyAccount) else {
            return nil
        }
        return SymmetricKey(data: data)
    }
    
    /// Checks if a master key already exists.
    public var hasMasterKey: Bool {
        return (try? retrieveMasterKey()) != nil
    }
    
    // MARK: - Owner PIN & Salt Management
    
    public func savePinHash(_ hash: String, salt: Data) throws {
        guard let hashData = hash.data(using: .utf8) else { return }
        try saveItem(data: hashData, account: pinHashAccount, accessPolicy: .deviceOnly)
        try saveItem(data: salt, account: pinSaltAccount, accessPolicy: .deviceOnly)
    }
    
    public func retrievePinHash() -> String? {
        guard let data = try? retrieveItem(account: pinHashAccount),
              let hash = String(data: data, encoding: .utf8) else {
            return nil
        }
        return hash
    }
    
    public func retrievePinSalt() -> Data? {
        return try? retrieveItem(account: pinSaltAccount)
    }
    
    // MARK: - Decoy Stealth PIN
    
    public func saveDecoyPinHash(_ hash: String) throws {
        guard let hashData = hash.data(using: .utf8) else { return }
        try saveItem(data: hashData, account: decoyPinAccount, accessPolicy: .deviceOnly)
    }
    
    public func retrieveDecoyPinHash() -> String? {
        guard let data = try? retrieveItem(account: decoyPinAccount),
              let hash = String(data: data, encoding: .utf8) else {
            return nil
        }
        return hash
    }
    
    // MARK: - Low-Level Keychain Primitives
    
    public enum AccessPolicy {
        case deviceOnly
        case passcodeProtected
    }
    
    private func saveItem(data: Data, account: String, accessPolicy: AccessPolicy) throws {
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Setup accessibility attribute: Strictly "ThisDeviceOnly" prevents iCloud Keychain backup/sync!
        let accessibility: CFString
        switch accessPolicy {
        case .deviceOnly:
            accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .passcodeProtected:
            accessibility = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultCryptoError.keychainError(status)
        }
    }
    
    private func retrieveItem(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw VaultCryptoError.keychainError(status)
        }
        return data
    }
    
    // MARK: - Self-Destruct / Panic Wipe
    
    /// Completely purges all cryptographic keys, PIN hashes, and secrets from Keychain.
    /// Once called, any encrypted data on disk becomes cryptographically unrecoverable mathematical noise.
    public func wipeAllKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        SecItemDelete(query as CFDictionary)
    }
}
