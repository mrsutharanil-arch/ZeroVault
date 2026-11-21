//
//  DeveloperProfileView.swift
//  ZeroVault
//
//  Official Company & Developer Profile View.
//  Exhibits developer credentials, sovereign security manifesto,
//  and enterprise privacy certifications.
//

import SwiftUI

public struct DeveloperProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.07).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Company & Developer Hero Card
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.15))
                                    .frame(width: 90, height: 90)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4), lineWidth: 2)
                                    )
                                
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            }
                            
                            VStack(spacing: 4) {
                                Text("Altexh")
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundColor(.white)
                                
                                Text("SOVEREIGN MOBILE ARCHITECTURES")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                                    .tracking(2)
                            }
                            
                            Text("Pioneering zero-knowledge, hardware-anchored privacy utilities engineered for absolute individual and corporate data sovereignty.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .lineSpacing(3)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.08))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(white: 0.14), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        
                        // Developer Information
                        VStack(alignment: .leading, spacing: 14) {
                            Text("LEAD ARCHITECT & DEVELOPER")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 10) {
                                ProfileInfoRow(label: "Lead Engineer", value: "Anil Suthar", icon: "person.badge.shield.checkmark.fill")
                                ProfileInfoRow(label: "GitHub Profile", value: "@mrsutharanil-arch", icon: "terminal.fill")
                                ProfileInfoRow(label: "Architecture", value: "Sovereign iOS Enclaves", icon: "cpu.fill")
                                ProfileInfoRow(label: "Cryptographic Standard", value: "CryptoKit AES-256-GCM", icon: "lock.shield.fill")
                                ProfileInfoRow(label: "Telemetry Footprint", value: "0% (100% Offline Air-Gapped)", icon: "antenna.radiowaves.left.and.right.slash")
                            }
                            .padding(14)
                            .background(Color(white: 0.08))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(white: 0.14), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // Security Manifesto & Core Principles
                        VStack(alignment: .leading, spacing: 14) {
                            Text("ZERO-KNOWLEDGE MANIFESTO")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                ManifestoRow(
                                    number: "01",
                                    title: "Owner-Only Dominion",
                                    description: "Data must be viewable only by the physical device owner through biometric authentication. No backdoors, no cloud escrow, no master overrides."
                                )
                                
                                ManifestoRow(
                                    number: "02",
                                    title: "Air-Gapped by Design",
                                    description: "Zero external network endpoints, zero cloud trackers, and strict hardware exclusion from iCloud and iTunes backups."
                                )
                                
                                ManifestoRow(
                                    number: "03",
                                    title: "Files & Photos Isolation",
                                    description: "Containers must never surface inside public file managers or camera rolls. Sensordata is captured directly to RAM."
                                )
                                
                                ManifestoRow(
                                    number: "04",
                                    title: "Forensic Multi-Pass Destruction",
                                    description: "File deletion must be active and cryptographic: random-byte overwrite followed by zeroization before disk unlinking."
                                )
                            }
                            .padding(14)
                            .background(Color(white: 0.08))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(white: 0.14), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // GitHub Repository Link Button
                        if let url = URL(string: "https://github.com/mrsutharanil-arch/ZeroVault") {
                            Link(destination: url) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.right.square.fill")
                                    Text("Visit GitHub Repository")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Text("© 2026 Altexh & Anil Suthar. All rights reserved.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.bottom, 24)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Company & Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                }
            }
        }
    }
}

// MARK: - Subcomponents
struct ProfileInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct ManifestoRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                .padding(6)
                .background(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.15))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
        }
    }
}
