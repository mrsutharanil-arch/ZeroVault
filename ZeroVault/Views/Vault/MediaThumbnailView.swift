//
//  MediaThumbnailView.swift
//  ZeroVault
//
//  Grid thumbnail item optimized for high-speed scanning of encrypted photos & videos.
//

import SwiftUI

public struct MediaThumbnailView: View {
    public let file: VaultFile
    public let onSelect: () -> Void
    
    public init(file: VaultFile, onSelect: @escaping () -> Void) {
        self.file = file
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomTrailing) {
                // Background Tile
                RoundedRectangle(cornerRadius: 10)
                    .fill(file.iconColor.opacity(0.16))
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(white: 0.16), lineWidth: 1)
                    )
                
                // Centered Icon
                VStack(spacing: 4) {
                    Image(systemName: file.iconName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(file.iconColor)
                    
                    Text(file.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Video Play Badge Overlay (if video)
                if file.isVideo {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("VIDEO")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(6)
                } else if file.isPhoto {
                    // Size Badge
                    Text(file.formattedSize)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(Color(white: 0.85))
                        .cornerRadius(4)
                        .padding(6)
                }
                
                // Top-left Lock Indicator
                VStack {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
