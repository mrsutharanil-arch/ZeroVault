//
//  EncryptedEnvelope.swift
//  ZeroVault
//
//  Cryptographic envelope definition for ZeroVault AES-256-GCM sealed containers.
//

import Foundation
import CryptoKit

/// Header magic identifier for ZeroVault format: "ZERO" + version byte
public struct VaultEnvelopeHeader {
    public static let magicBytes = Data([0x5A, 0x45, 0x52, 0x4F]) // "ZERO"
    public static let formatVersion: UInt8 = 0x02
    public static let headerSize = 5 // 4 bytes magic + 1 byte version
}

/// Metadata encrypted along with the file payload inside the sealed cryptographic box.
/// This prevents any file names, MIME types, or creation dates from leaking to the filesystem.
public struct EncryptedFileMetadata: Codable {
    public let id: UUID
    public let originalFilename: String
    public let title: String
    public let mimeType: String
    public let categoryRaw: String
    public let fileSize: Int64
    public let createdAt: Date
    public let checksumSha256: String
    public let userNotes: String?
    
    public init(
        id: UUID = UUID(),
        originalFilename: String,
        title: String,
        mimeType: String,
        category: VaultCategory,
        fileSize: Int64,
        createdAt: Date = Date(),
        checksumSha256: String,
        userNotes: String? = nil
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.title = title
        self.mimeType = mimeType
        self.categoryRaw = category.rawValue
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.checksumSha256 = checksumSha256
        self.userNotes = userNotes
    }
    
    public var category: VaultCategory {
        VaultCategory(rawValue: categoryRaw) ?? .documents
    }
}

/// Binary container packaged into disk:
/// v2: [MAGIC (4B)] [VERSION 0x02 (1B)] [NONCE (12B)] [META_TAG (16B)] [PAYLOAD_TAG (16B)] [METADATA_LEN (4B)] [ENCRYPTED_METADATA] [ENCRYPTED_PAYLOAD]
/// v1: [MAGIC (4B)] [VERSION 0x01 (1B)] [NONCE (12B)] [TAG (16B)] [METADATA_LEN (4B)] [ENCRYPTED_METADATA] [ENCRYPTED_PAYLOAD]
public struct VaultSealedPackage {
    public let header: Data
    public let nonce: Data
    public let metaTag: Data
    public let payloadTag: Data
    public let encryptedMetadata: Data
    public let encryptedPayload: Data
    
    public init(
        header: Data = VaultEnvelopeHeader.magicBytes + [VaultEnvelopeHeader.formatVersion],
        nonce: Data,
        metaTag: Data,
        payloadTag: Data,
        encryptedMetadata: Data,
        encryptedPayload: Data
    ) {
        self.header = header
        self.nonce = nonce
        self.metaTag = metaTag
        self.payloadTag = payloadTag
        self.encryptedMetadata = encryptedMetadata
        self.encryptedPayload = encryptedPayload
    }
    
    public func serialize() -> Data {
        var data = Data()
        data.append(VaultEnvelopeHeader.magicBytes)
        data.append(VaultEnvelopeHeader.formatVersion) // 0x02
        
        // Nonce (12 bytes)
        data.append(nonce)
        // Metadata Tag (16 bytes)
        data.append(metaTag)
        // Payload Tag (16 bytes)
        data.append(payloadTag)
        
        // Length of encrypted metadata (UInt32 big endian)
        var metaLen = UInt32(encryptedMetadata.count).bigEndian
        data.append(Data(bytes: &metaLen, count: 4))
        
        // Encrypted metadata
        data.append(encryptedMetadata)
        
        // Encrypted payload
        data.append(encryptedPayload)
        
        return data
    }
    
    public static func deserialize(from data: Data) throws -> VaultSealedPackage {
        guard data.count >= 5 else {
            throw VaultCryptoError.corruptedFile("File size too small for ZeroVault envelope header.")
        }
        
        let magic = data.subdata(in: 0..<4)
        guard magic == VaultEnvelopeHeader.magicBytes else {
            throw VaultCryptoError.invalidMagicBytes
        }
        
        let version = data[4]
        
        if version == 0x02 {
            // Version 2 format: dual-tag envelope
            guard data.count >= (5 + 12 + 16 + 16 + 4) else {
                throw VaultCryptoError.corruptedFile("Truncated v2 package header.")
            }
            
            var offset = 5
            let nonce = data.subdata(in: offset..<(offset + 12))
            offset += 12
            
            let metaTag = data.subdata(in: offset..<(offset + 16))
            offset += 16
            
            let payloadTag = data.subdata(in: offset..<(offset + 16))
            offset += 16
            
            let metaLenData = data.subdata(in: offset..<(offset + 4))
            let metaLen = metaLenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            offset += 4
            
            let metaEnd = offset + Int(metaLen)
            guard data.count >= metaEnd else {
                throw VaultCryptoError.corruptedFile("Truncated metadata in v2 package.")
            }
            
            let encMetadata = data.subdata(in: offset..<metaEnd)
            let encPayload = data.subdata(in: metaEnd..<data.count)
            
            return VaultSealedPackage(
                header: data.subdata(in: 0..<5),
                nonce: nonce,
                metaTag: metaTag,
                payloadTag: payloadTag,
                encryptedMetadata: encMetadata,
                encryptedPayload: encPayload
            )
        } else if version == 0x01 {
            // Version 1 backwards-compatible parser
            guard data.count >= (5 + 12 + 16 + 4) else {
                throw VaultCryptoError.corruptedFile("Truncated v1 package header.")
            }
            
            var offset = 5
            let nonce = data.subdata(in: offset..<(offset + 12))
            offset += 12
            
            let tag = data.subdata(in: offset..<(offset + 16))
            offset += 16
            
            let metaLenData = data.subdata(in: offset..<(offset + 4))
            let metaLen = metaLenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            offset += 4
            
            let metaEnd = offset + Int(metaLen)
            guard data.count >= metaEnd else {
                throw VaultCryptoError.corruptedFile("Truncated metadata in v1 package.")
            }
            
            let encMetadata = data.subdata(in: offset..<metaEnd)
            let encPayload = data.subdata(in: metaEnd..<data.count)
            
            return VaultSealedPackage(
                header: data.subdata(in: 0..<5),
                nonce: nonce,
                metaTag: tag,
                payloadTag: tag,
                encryptedMetadata: encMetadata,
                encryptedPayload: encPayload
            )
        } else {
            throw VaultCryptoError.unsupportedVersion(version)
        }
    }
}

public enum VaultCryptoError: LocalizedError {
    case invalidMagicBytes
    case unsupportedVersion(UInt8)
    case corruptedFile(String)
    case decryptionFailed
    case keyDerivationFailed
    case keychainError(OSStatus)
    case biometricsFailed(String)
    case fileNotFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidMagicBytes:
            return "Invalid file format. Not a valid ZeroVault encrypted file."
        case .unsupportedVersion(let v):
            return "Unsupported vault container version: \(v)."
        case .corruptedFile(let reason):
            return "Cryptographic package is corrupted or has been tampered with: \(reason)"
        case .decryptionFailed:
            return "Decryption failed. Authentication tag mismatch or invalid master key."
        case .keyDerivationFailed:
            return "Could not derive cryptographic key from hardware enclave."
        case .keychainError(let status):
            return "Secure Enclave Keychain error: \(status)"
        case .biometricsFailed(let msg):
            return "Biometric authentication failed: \(msg)"
        case .fileNotFound:
            return "Encrypted file could not be found in vault storage."
        }
    }
}
