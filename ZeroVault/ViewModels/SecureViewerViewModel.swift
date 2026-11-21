//
//  SecureViewerViewModel.swift
//  ZeroVault
//
//  In-Memory decryptor and viewer controller. Ensures that cleartext data
//  exists only in RAM while actively displayed on screen, and is immediately
//  zeroized upon dismissal or app backgrounding.
//

import SwiftUI
import CryptoKit
import PDFKit

public final class SecureViewerViewModel: ObservableObject {
    public let file: VaultFile
    
    @Published public var isLoading: Bool = true
    @Published public var errorMessage: String? = nil
    
    // In-memory cleartext representations (never persisted to disk!)
    @Published public var decryptedData: Data? = nil
    @Published public var decryptedImage: UIImage? = nil
    @Published public var decryptedText: String? = nil
    @Published public var pdfDocument: PDFDocument? = nil
    
    private let crypto = CryptographyService.shared
    private let storage = StorageSecurityService.shared
    private let keychain = KeychainService.shared
    
    public init(file: VaultFile) {
        self.file = file
        decryptFileInRAM()
    }
    
    deinit {
        purgeFromMemory()
    }
    
    // MARK: - Decrypt Directly to RAM
    
    public func decryptFileInRAM() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let masterKey = try? self.keychain.retrieveMasterKey() else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Could not access hardware master key."
                }
                return
            }
            
            do {
                let ciphertext = try self.storage.readEncryptedPayload(filename: self.file.diskFilename)
                let result = try self.crypto.decrypt(encryptedData: ciphertext, using: masterKey)
                var cleartext = result.payload
                
                // Render into memory types
                var loadedImage: UIImage? = nil
                var loadedText: String? = nil
                var loadedPDF: PDFDocument? = nil
                
                if self.file.isPhoto {
                    loadedImage = UIImage(data: cleartext)
                } else if self.file.isPDF {
                    loadedPDF = PDFDocument(data: cleartext)
                } else if self.file.isText {
                    loadedText = String(data: cleartext, encoding: .utf8)
                }
                
                DispatchQueue.main.async {
                    self.decryptedData = cleartext
                    self.decryptedImage = loadedImage
                    self.decryptedText = loadedText
                    self.pdfDocument = loadedPDF
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Decryption failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Immediate Memory Cleansing
    
    public func purgeFromMemory() {
        if var data = decryptedData {
            crypto.secureWipe(data: &data)
        }
        decryptedData = nil
        decryptedImage = nil
        decryptedText = nil
        pdfDocument = nil
    }
}
