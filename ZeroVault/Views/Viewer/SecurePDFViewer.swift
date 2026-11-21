//
//  SecurePDFViewer.swift
//  ZeroVault
//
//  PDF viewer rendered directly from in-memory PDFDocument.
//

import SwiftUI
import PDFKit

public struct SecurePDFViewer: UIViewRepresentable {
    public let document: PDFDocument
    
    public init(document: PDFDocument) {
        self.document = document
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1.0)
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document != document {
            uiView.document = document
        }
    }
}
