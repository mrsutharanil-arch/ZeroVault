//
//  VaultFileRow.swift
//  ZeroVault
//
//  File row representing an encrypted vault item with security badges,
//  file size, and quick actions.
//

import SwiftUI

public struct VaultFileRow: View {
    public let file: VaultFile
    public let onSelect: () -> Void
    public let onDelete: () -> Void
    
    public init(file: VaultFile, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.file = file
        self.onSelect = onSelect
        self.onDelete = onDelete
    }
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Category Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(file.iconColor.opacity(0.18))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(file.iconColor.opacity(0.35), lineWidth: 1)
                        )
                    
                    Image(systemName: file.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(file.iconColor)
                }
                
                // File Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        
                        Text(file.formattedSize)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(file.formattedDate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Shred / Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(white: 0.3))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(white: 0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(white: 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
