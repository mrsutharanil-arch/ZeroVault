//
//  SecureImageViewer.swift
//  ZeroVault
//
//  Zoomable image viewer rendered directly from memory buffers.
//

import SwiftUI

public struct SecureImageViewer: View {
    public let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    public init(image: UIImage) {
        self.image = image
    }
    
    public var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(1.0, min(lastScale * value, 5.0))
                        }
                        .onEnded { value in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
