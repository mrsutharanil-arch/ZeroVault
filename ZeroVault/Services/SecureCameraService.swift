//
//  SecureCameraService.swift
//  ZeroVault
//
//  AVFoundation camera pipeline that captures photos and videos directly into RAM.
//  Bypasses PhotoKit and iOS Camera Roll entirely. Encrypts immediately in memory
//  and stores directly into the isolated ZeroVault storage.
//

import Foundation
import AVFoundation
import UIKit

public protocol SecureCameraDelegate: AnyObject {
    func didCaptureSecurePhoto(data: Data)
    func cameraDidFail(with error: Error)
}

public final class SecureCameraService: NSObject, ObservableObject {
    public static let shared = SecureCameraService()
    
    @Published public var isSessionRunning: Bool = false
    @Published public var cameraPosition: AVCaptureDevice.Position = .back
    @Published public var flashMode: AVCaptureDevice.FlashMode = .auto
    
    public let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.zerovault.camera.queue")
    
    public weak var delegate: SecureCameraDelegate?
    private var photoContinuation: CheckedContinuation<Data, Error>?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup Session
    
    public func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            // Add video input
            do {
                var defaultVideoDevice: AVCaptureDevice?
                if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    defaultVideoDevice = backCameraDevice
                } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    defaultVideoDevice = frontCameraDevice
                }
                
                guard let videoDevice = defaultVideoDevice else {
                    self.captureSession.commitConfiguration()
                    return
                }
                
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                    self.videoDeviceInput = videoInput
                }
                
                // Add photo output
                if self.captureSession.canAddOutput(self.photoOutput) {
                    self.captureSession.addOutput(self.photoOutput)
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                }
                
                self.captureSession.commitConfiguration()
                self.startSession()
            } catch {
                self.captureSession.commitConfiguration()
                print("Failed to configure secure camera: \(error)")
            }
        }
    }
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Capture Photo Directly to RAM
    
    public func captureDirectPhoto() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: VaultCryptoError.corruptedFile("Camera unavailable"))
                    return
                }
                self.photoContinuation = continuation
                
                let settings = AVCapturePhotoSettings()
                if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                    settings.flashMode = self.flashMode
                }
                settings.isHighResolutionPhotoEnabled = true
                
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    // MARK: - Toggle Camera Lens
    
    public func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let currentPosition = self.cameraPosition
            let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                return
            }
            
            self.captureSession.beginConfiguration()
            if let currentInput = self.videoDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.videoDeviceInput = newInput
                DispatchQueue.main.async {
                    self.cameraPosition = newPosition
                }
            } else if let currentInput = self.videoDeviceInput {
                self.captureSession.addInput(currentInput)
            }
            
            self.captureSession.commitConfiguration()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension SecureCameraService: AVCapturePhotoCaptureDelegate {
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            photoContinuation?.resume(throwing: error)
            photoContinuation = nil
            return
        }
        
        guard let fileData = photo.fileDataRepresentation() else {
            photoContinuation?.resume(throwing: VaultCryptoError.corruptedFile("Failed to capture raw photo data"))
            photoContinuation = nil
            return
        }
        
        // Return raw in-memory JPEG/HEIC data without touching photo library
        photoContinuation?.resume(returning: fileData)
        photoContinuation = nil
    }
}
