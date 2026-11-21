//
//  LockScreenView.swift
//  ZeroVault
//
//  Ultra-secure Owner-Only authentication screen with Face ID biometrics,
//  scrambled PIN keypad, and anti-shoulder surfing safeguards.
//

import SwiftUI

public struct LockScreenView: View {
    @ObservedObject public var authVM: AuthViewModel
    @State private var pulseAnimation: Bool = false
    
    public init(authVM: AuthViewModel) {
        self.authVM = authVM
    }
    
    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.09),
                    Color(red: 0.02, green: 0.03, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Shield Vault Icon & Biometric Scanner Ring
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(pulseAnimation ? 0.4 : 0.1), lineWidth: pulseAnimation ? 4 : 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseAnimation ? 1.08 : 1.0)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 74, height: 74)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                }
                .onAppear {
                    pulseAnimation = true
                    // Automatically prompt Face ID on view presentation if not locked out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        authVM.triggerFaceID()
                    }
                }
                
                // Title & Subtitle
                VStack(spacing: 6) {
                    Text("ZEROVAULT")
                        .font(ZeroVaultFont.heroTitle())
                        .foregroundColor(.white)
                        .tracking(3)
                    
                    Text(authVM.isSettingUpPin ? (authVM.setupStep == 1 ? "SET MASTER OWNER PIN" : "CONFIRM MASTER PIN") : "ALTEXH • OWNER SOVEREIGN ACCESS")
                        .font(ZeroVaultFont.cryptoAudit())
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        .tracking(2)
                }
                
                // Error / Lockout Banner
                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }
                
                // PIN Dots
                HStack(spacing: 16) {
                    ForEach(0..<authVM.pinLength, id: \.self) { index in
                        Circle()
                            .fill(index < authVM.pinInput.count ? Color(red: 0.2, green: 0.8, blue: 0.6) : Color(white: 0.25))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4), lineWidth: 1)
                            )
                            .scaleEffect(index < authVM.pinInput.count ? 1.15 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: authVM.pinInput.count)
                    }
                }
                .padding(.vertical, 8)
                .offset(x: authVM.isShaking ? -10 : 0)
                .animation(authVM.isShaking ? Animation.default.repeatCount(4, autoreverses: true).speed(4) : .default, value: authVM.isShaking)
                
                Spacer()
                
                // Keypad
                VStack(spacing: 14) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 24) {
                            ForEach(0..<3) { col in
                                let index = row * 3 + col
                                if index < authVM.keypadDigits.count {
                                    let digit = authVM.keypadDigits[index]
                                    KeypadButton(title: "\(digit)", subtitle: keypadLetterSubtitle(for: digit)) {
                                        authVM.appendDigit(digit)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bottom row: Biometrics / Scramble / 0 / Delete
                    HStack(spacing: 24) {
                        // Left action: Face ID trigger
                        Button(action: {
                            authVM.triggerFaceID()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.14).opacity(0.85))
                                    .frame(width: 74, height: 74)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(white: 0.25).opacity(0.6), lineWidth: 1)
                                    )
                                Image(systemName: "faceid")
                                    .font(.system(size: 26, weight: .regular))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            }
                        }
                        
                        // Digit 0 (or 10th digit)
                        if authVM.keypadDigits.count > 9 {
                            let lastDigit = authVM.keypadDigits[9]
                            KeypadButton(title: "\(lastDigit)", subtitle: keypadLetterSubtitle(for: lastDigit)) {
                                authVM.appendDigit(lastDigit)
                            }
                        }
                        
                        // Right action: Delete / Backspace
                        Button(action: {
                            authVM.deleteDigit()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.14).opacity(0.85))
                                    .frame(width: 74, height: 74)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(white: 0.25).opacity(0.6), lineWidth: 1)
                                    )
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Security Audit Footer
                HStack(spacing: 12) {
                    SecurityBadge(title: "AES-256-GCM", icon: "lock.shield.fill")
                    SecurityBadge(title: "NO BACKUP", icon: "icloud.slash.fill", color: Color(red: 1.0, green: 0.75, blue: 0.3))
                    SecurityBadge(title: "RAM ONLY", icon: "memorychip.fill", color: Color(red: 0.4, green: 0.7, blue: 1.0))
                }
                .padding(.bottom, 20)
            }
        }
    }
    // Helper for Apple iOS Keypad Subtitles
    private func keypadLetterSubtitle(for digit: Int) -> String {
        switch digit {
        case 2: return "ABC"
        case 3: return "DEF"
        case 4: return "GHI"
        case 5: return "JKL"
        case 6: return "MNO"
        case 7: return "PQRS"
        case 8: return "TUV"
        case 9: return "WXYZ"
        case 0: return "+"
        default: return ""
        }
    }
}

// MARK: - Keypad Button View (Authentic Apple iOS SF Pro Rounded Front Design)
struct KeypadButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.16).opacity(0.85))
                    .frame(width: 74, height: 74)
                    .overlay(
                        Circle()
                            .stroke(Color(white: 0.28).opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                
                VStack(spacing: 0) {
                    Text(title)
                        .font(ZeroVaultFont.keypadDigit())
                        .foregroundColor(.white)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 9, weight: .bold, design: .default))
                            .foregroundColor(Color.gray.opacity(0.85))
                            .tracking(2)
                            .padding(.top, -1)
                    }
                }
            }
        }
        .buttonStyle(KeypadPressStyle())
    }
}

struct KeypadPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
