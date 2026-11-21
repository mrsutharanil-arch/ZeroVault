//
//  SecureCameraView.swift
//  ZeroVault
//
//  Direct-to-RAM camera UI that writes zero bytes to the iOS Camera Roll.
//  Encrypts captured image instantly with AES-256-GCM.
//

import SwiftUI
import AVFoundation

public struct SecureCameraView: View {
    @ObservedObject public var vaultVM: VaultViewModel
    @StateObject private var cameraService = SecureCameraService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isCapturing: Bool = false
    @State private var flashAnimation: Bool = false
    @State private var showSuccessBanner: Bool = false
    
    public init(vaultVM: VaultViewModel) {
        self.vaultVM = vaultVM
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Viewfinder Preview
            CameraPreviewRepresentable(session: cameraService.captureSession)
                .ignoresSafeArea()
            
            // Flash Effect upon capture
            if flashAnimation {
                Color.white.ignoresSafeArea()
                    .transition(.opacity)
            }
            
            VStack {
                // Top Control Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Secure Mode Badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .frame(width: 8, height: 8)
                        Text("RAM ONLY • NO CAMERA ROLL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Flip Lens Button
                    Button(action: {
                        cameraService.flipCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Success Badge
                if showSuccessBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        Text("Photo Encrypted with AES-256-GCM")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom Shutter Bar
                HStack {
                    Spacer()
                    
                    // Shutter Button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.6))
                                .frame(width: 66, height: 66)
                                .scaleEffect(isCapturing ? 0.85 : 1.0)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .disabled(isCapturing)
                    
                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraService.configureSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
    
    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        
        withAnimation(.easeInOut(duration: 0.1)) {
            flashAnimation = true
        }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                flashAnimation = false
            }
        }
        
        Task {
            do {
                let photoData = try await cameraService.captureDirectPhoto()
                try vaultVM.importCameraPhoto(data: photoData)
                
                await MainActor.run {
                    withAnimation {
                        showSuccessBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                }
            }
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
