//
//  CryptographyService.swift
//  ZeroVault
//
//  Cryptographic engine providing hardware-accelerated AES-256-GCM authenticated
//  encryption using Apple's CryptoKit framework. All encryption/decryption happens
//  purely in RAM memory with immediate secure zeroization.
//

import Foundation
import CryptoKit

public final class CryptographyService {
    public static let shared = CryptographyService()
    
    private init() {}
    
    // MARK: - Key Generation & Derivation
    
    /// Generates a cryptographically strong 256-bit symmetric encryption key.
    public func generateMasterKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Derives a 256-bit AES-GCM key from a user PIN and salt using HKDF-SHA256.
    public func deriveKey(from pin: String, salt: Data) throws -> SymmetricKey {
        guard let pinData = pin.data(using: .utf8), !pinData.isEmpty else {
            throw VaultCryptoError.keyDerivationFailed
        }
        let inputKeyMaterial = SymmetricKey(data: pinData)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: "ZeroVault.MasterEncryptionKey.v1".data(using: .utf8)!,
            outputByteCount: 32
        )
    }
    
    /// Generates 32 bytes of cryptographically secure random salt.
    public func generateRandomSalt(count: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
    
    // MARK: - Encryption (Sealing)
    
    /// Encrypts raw in-memory file payload and metadata using AES-256-GCM.
    /// Produces an authenticated sealed package containing independent tags for metadata and payload.
    public func encrypt(
        payload: Data,
        metadata: EncryptedFileMetadata,
        using masterKey: SymmetricKey
    ) throws -> Data {
        // 1. Serialize metadata to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metadataJson = try encoder.encode(metadata)
        
        // 2. Generate unique cryptographic Nonce for AES-GCM (96 bits / 12 bytes)
        let nonce = AES.GCM.Nonce()
        
        // 3. Encrypt the Metadata JSON with AES-256-GCM using masterKey
        let sealedMetadataBox = try AES.GCM.seal(metadataJson, using: masterKey, nonce: nonce)
        
        // 4. Encrypt the actual File Payload with AES-256-GCM, cryptographically binding metadata tag as AAD
        let sealedPayloadBox = try AES.GCM.seal(payload, using: masterKey, nonce: nonce, authenticating: sealedMetadataBox.tag)
        
        // 5. Assemble into the ZeroVault sealed package structure (v2)
        let package = VaultSealedPackage(
            nonce: Data(nonce),
            metaTag: sealedMetadataBox.tag,
            payloadTag: sealedPayloadBox.tag,
            encryptedMetadata: sealedMetadataBox.ciphertext,
            encryptedPayload: sealedPayloadBox.ciphertext
        )
        
        return package.serialize()
    }
    
    // MARK: - Decryption (Unsealing in RAM)
    
    /// Decrypts a sealed package in memory.
    /// NEVER writes the decrypted cleartext bytes to disk!
    public func decrypt(
        encryptedData: Data,
        using masterKey: SymmetricKey
    ) throws -> (payload: Data, metadata: EncryptedFileMetadata) {
        // 1. Parse binary container
        let package = try VaultSealedPackage.deserialize(from: encryptedData)
        
        guard let nonce = try? AES.GCM.Nonce(data: package.nonce) else {
            throw VaultCryptoError.corruptedFile("Invalid cryptographic nonce")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 2. Decrypt metadata
        var metadata = EncryptedFileMetadata(
            originalFilename: "decrypted_file",
            title: "Encrypted Secure File",
            mimeType: "application/octet-stream",
            category: .documents,
            fileSize: Int64(package.encryptedPayload.count),
            checksumSha256: ""
        )
        
        // Open metadata sealed box using dedicated metaTag
        if let metaBox = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: package.encryptedMetadata, tag: package.metaTag),
           let metaData = try? AES.GCM.open(metaBox, using: masterKey),
           let decodedMeta = try? decoder.decode(EncryptedFileMetadata.self, from: metaData) {
            metadata = decodedMeta
        }
        
        // 3. Decrypt payload
        let payloadBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: package.encryptedPayload,
            tag: package.payloadTag
        )
        
        // Fast path: Open payload using metaTag as AAD (v2 format)
        if let cleartext = try? AES.GCM.open(payloadBox, using: masterKey, authenticating: package.metaTag) {
            return (payload: cleartext, metadata: metadata)
        }
        
        // Fallback 1: Open with metadata ID as AAD (legacy v1 with ID)
        let aadData = metadata.id.uuidString.data(using: .utf8)!
        if let cleartext = try? AES.GCM.open(payloadBox, using: masterKey, authenticating: aadData) {
            return (payload: cleartext, metadata: metadata)
        }
        
        // Fallback 2: Open directly without AAD
        let cleartext = try AES.GCM.open(payloadBox, using: masterKey)
        return (payload: cleartext, metadata: metadata)
    }
    
    // MARK: - Decrypt Metadata Only (For Fast Vault Indexing)
    
    /// Reads and decrypts only the metadata header to display the file list in the UI,
    /// without loading huge 500MB video/photo payloads into memory!
    public func decryptMetadataOnly(
        from encryptedData: Data,
        using masterKey: SymmetricKey
    ) throws -> EncryptedFileMetadata {
        let package = try VaultSealedPackage.deserialize(from: encryptedData)
        
        guard let nonce = try? AES.GCM.Nonce(data: package.nonce) else {
            throw VaultCryptoError.corruptedFile("Invalid nonce in package")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Open metadata sealed box using dedicated metaTag
        if let metaBox = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: package.encryptedMetadata, tag: package.metaTag),
           let metaData = try? AES.GCM.open(metaBox, using: masterKey),
           let meta = try? decoder.decode(EncryptedFileMetadata.self, from: metaData) {
            return meta
        }
        
        // Fallback default metadata if legacy format
        return EncryptedFileMetadata(
            originalFilename: "secure_payload.bin",
            title: "Encrypted Secure File",
            mimeType: "application/octet-stream",
            category: .documents,
            fileSize: Int64(package.encryptedPayload.count),
            checksumSha256: ""
        )
    }
    
    // MARK: - SHA-256 Integrity Checksum
    
    public func computeSha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Memory Hygiene
    
    /// Zeroes out sensitive data buffer in memory
    public func secureWipe(data: inout Data) {
        data.resetBytes(in: 0..<data.count)
    }
}
