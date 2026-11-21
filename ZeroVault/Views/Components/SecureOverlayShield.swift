//
//  SecureOverlayShield.swift
//  ZeroVault
//
//  Hardware and UI shielding layer that obscures the app in the iOS App Switcher
//  and detects active screen recording or external AirPlay mirroring.
//

import SwiftUI

public struct SecureOverlayShield: View {
    public let isRecording: Bool
    
    public init(isRecording: Bool = false) {
        self.isRecording = isRecording
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(isRecording ? 0.6 : 0.2), lineWidth: 3)
                        .frame(width: 110, height: 110)
                    
                    Circle()
                        .fill(Color(white: 0.1))
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: isRecording ? "record.circle.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(isRecording ? .red : Color(red: 0.2, green: 0.8, blue: 0.6))
                }
                
                VStack(spacing: 8) {
                    Text(isRecording ? "SCREEN RECORDING DETECTED" : "ZEROVAULT SECURED")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                    
                    Text(isRecording ? "Content hidden to prevent screen capture leakage." : "Owner authentication required to view contents.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
