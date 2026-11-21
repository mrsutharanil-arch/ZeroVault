//
//  SecureTextViewer.swift
//  ZeroVault
//
//  Confidential text, markdown, and code viewer.
//

import SwiftUI

public struct SecureTextViewer: View {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(Color(white: 0.9))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(white: 0.08))
                    .cornerRadius(12)
            }
            .padding(16)
        }
    }
}
