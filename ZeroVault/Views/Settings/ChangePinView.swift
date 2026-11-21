//
//  ChangePinView.swift
//  ZeroVault
//
//  Secure Master Owner PIN Change Interface.
//  Enforces 3-step verification: Current PIN -> New PIN -> Confirm PIN.
//

import SwiftUI

public struct ChangePinView: View {
    @Environment(\.dismiss) private var dismiss
    private let authService = AuthenticationService.shared
    
    @State private var currentStep: Int = 1 // 1: Current PIN, 2: New PIN, 3: Confirm PIN
    @State private var pinInput: String = ""
    @State private var oldPin: String = ""
    @State private var newPin: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSuccess: Bool = false
    @State private var isShaking: Bool = false
    
    private let pinLength: Int = 6
    private let digits: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.07).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Shield Icon
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: isSuccess ? "checkmark.shield.fill" : "key.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(isSuccess ? Color(red: 0.2, green: 0.8, blue: 0.6) : Color(red: 0.4, green: 0.7, blue: 1.0))
                    }
                    
                    // Step Title
                    VStack(spacing: 6) {
                        Text(stepTitle)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2)
                        
                        Text(stepSubtitle)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .tracking(1)
                    }
                    
                    // Error message
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // PIN Dots
                    HStack(spacing: 16) {
                        ForEach(0..<pinLength, id: \.self) { idx in
                            Circle()
                                .fill(idx < pinInput.count ? Color(red: 0.2, green: 0.8, blue: 0.6) : Color(white: 0.22))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4), lineWidth: 1)
                                )
                                .scaleEffect(idx < pinInput.count ? 1.15 : 1.0)
                        }
                    }
                    .padding(.vertical, 10)
                    .offset(x: isShaking ? -10 : 0)
                    .animation(isShaking ? Animation.default.repeatCount(4, autoreverses: true).speed(4) : .default, value: isShaking)
                    
                    Spacer()
                    
                    // Keypad
                    VStack(spacing: 12) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 24) {
                                ForEach(0..<3) { col in
                                    let digit = row * 3 + col + 1
                                    KeypadButton(title: "\(digit)", subtitle: "") {
                                        appendDigit(digit)
                                    }
                                }
                            }
                        }
                        
                        // Bottom row
                        HStack(spacing: 24) {
                            Spacer().frame(width: 72, height: 72)
                            
                            KeypadButton(title: "0", subtitle: "") {
                                appendDigit(0)
                            }
                            
                            Button(action: deleteDigit) {
                                ZStack {
                                    Circle()
                                        .fill(Color(white: 0.14))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "delete.left.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Change Master PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "CURRENT PIN"
        case 2: return "NEW MASTER PIN"
        case 3: return "CONFIRM NEW PIN"
        default: return "SUCCESS"
        }
    }
    
    private var stepSubtitle: String {
        switch currentStep {
        case 1: return "STEP 1 OF 3: VERIFY CURRENT OWNER PIN"
        case 2: return "STEP 2 OF 3: ENTER NEW 6-DIGIT PIN"
        case 3: return "STEP 3 OF 3: CONFIRM NEW 6-DIGIT PIN"
        default: return "MASTER PIN UPDATED SUCCESSFULLY"
        }
    }
    
    private func appendDigit(_ digit: Int) {
        guard pinInput.count < pinLength else { return }
        pinInput.append("\(digit)")
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        
        if pinInput.count == pinLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                processStep()
            }
        }
    }
    
    private func deleteDigit() {
        guard !pinInput.isEmpty else { return }
        pinInput.removeLast()
    }
    
    private func processStep() {
        if currentStep == 1 {
            // Verify old PIN
            let result = authService.authenticateWithPin(pinInput)
            switch result {
            case .success:
                oldPin = pinInput
                pinInput = ""
                errorMessage = nil
                currentStep = 2
            default:
                triggerError(message: "Incorrect current PIN. Verification failed.")
            }
        } else if currentStep == 2 {
            newPin = pinInput
            pinInput = ""
            errorMessage = nil
            currentStep = 3
        } else if currentStep == 3 {
            if pinInput == newPin {
                do {
                    let success = try authService.changeOwnerPin(currentPin: oldPin, newPin: newPin)
                    if success {
                        isSuccess = true
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } else {
                        triggerError(message: "Failed to update PIN.")
                    }
                } catch {
                    triggerError(message: error.localizedDescription)
                }
            } else {
                pinInput = ""
                triggerError(message: "PINs did not match. Please re-enter your new PIN.")
                currentStep = 2
            }
        }
    }
    
    private func triggerError(message: String) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        errorMessage = message
        pinInput = ""
        isShaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isShaking = false
        }
    }
}
