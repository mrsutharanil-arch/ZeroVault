//
//  FastScrollScrubber.swift
//  ZeroVault
//
//  Interactive timeline scrubber along the right edge enabling fast scrubbing
//  and jumping across media groups with instant haptic feedback.
//

import SwiftUI

public struct FastScrollScrubber: View {
    public let groups: [VaultMediaGroup]
    public let onSelectGroup: (String) -> Void
    
    @State private var activeScrubTitle: String? = nil
    @State private var isDragging: Bool = false
    
    private let haptic = UISelectionFeedbackGenerator()
    
    public init(groups: [VaultMediaGroup], onSelectGroup: @escaping (String) -> Void) {
        self.groups = groups
        self.onSelectGroup = onSelectGroup
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Floating Bubble when dragging
            if let activeTitle = activeScrubTitle, isDragging {
                Text(activeTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.5), radius: 6)
                    .transition(.opacity)
            }
            
            // Scrubber Bar
            VStack(spacing: 4) {
                ForEach(groups) { group in
                    Circle()
                        .fill(activeScrubTitle == group.title ? Color(red: 0.2, green: 0.8, blue: 0.6) : Color(white: 0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(activeScrubTitle == group.title ? 1.5 : 1.0)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        handleDrag(location: value.location)
                    }
                    .onEnded { _ in
                        isDragging = false
                        activeScrubTitle = nil
                    }
            )
        }
    }
    
    private func handleDrag(location: CGPoint) {
        guard !groups.isEmpty else { return }
        let totalHeight = CGFloat(groups.count * 12)
        let clampedY = max(0, min(location.y, totalHeight))
        let progress = clampedY / max(1, totalHeight)
        let index = min(groups.count - 1, Int(progress * CGFloat(groups.count)))
        
        let targetGroup = groups[index]
        if activeScrubTitle != targetGroup.title {
            activeScrubTitle = targetGroup.title
            haptic.selectionChanged()
            onSelectGroup(targetGroup.id)
        }
    }
}
