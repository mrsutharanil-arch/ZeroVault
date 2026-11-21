//
//  SecurityBadge.swift
//  ZeroVault
//
//  Compact cybersecurity status badge highlighting zero-knowledge attributes.
//

import SwiftUI

public struct SecurityBadge: View {
    public let title: String
    public let icon: String
    public let color: Color
    
    public init(title: String, icon: String = "lock.shield.fill", color: Color = Color(red: 0.2, green: 0.8, blue: 0.6)) {
        self.title = title
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .overlay(
            Capsule()
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
