//
//  SecureMediaGalleryView.swift
//  ZeroVault
//
//  Fullscreen paging gallery for photos and videos.
//  Enables smooth horizontal swiping across in-memory media items with
//  video playback controls and interactive image zooming.
//

import SwiftUI

public struct SecureMediaGalleryView: View {
    @ObservedObject public var vaultVM: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingInfo: Bool = false
    @State private var isPlayingVideo: Bool = false
    @State private var videoProgress: Double = 0.35
    
    public init(vaultVM: VaultViewModel) {
        self.vaultVM = vaultVM
    }
    
    private var currentFile: VaultFile? {
        guard vaultVM.activeGalleryIndex >= 0,
              vaultVM.activeGalleryIndex < vaultVM.activeGalleryFiles.count else {
            return nil
        }
        return vaultVM.activeGalleryFiles[vaultVM.activeGalleryIndex]
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Swiping Page Carousel
                TabView(selection: $vaultVM.activeGalleryIndex) {
                    ForEach(Array(vaultVM.activeGalleryFiles.enumerated()), id: \.element.id) { index, file in
                        GalleryPageItem(file: file, isPlaying: $isPlayingVideo, progress: $videoProgress)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Overlay Top & Bottom Bars
                VStack {
                    // Top Navigation Bar
                    topBar
                    Spacer()
                    // Bottom Controls Bar
                    bottomBar
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingInfo) {
                if let file = currentFile {
                    SecureFileViewerContainer(file: file)
                }
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Spacer()
            
            // Index counter
            if let file = currentFile {
                VStack(spacing: 2) {
                    Text(file.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(vaultVM.activeGalleryIndex + 1) of \(vaultVM.activeGalleryFiles.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                }
            }
            
            Spacer()
            
            Button(action: {
                showingInfo = true
            }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 48)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let file = currentFile, file.isVideo {
                // Video Progress Bar
                HStack(spacing: 10) {
                    Text("0:14")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Slider(value: $videoProgress, in: 0...1)
                        .accentColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    
                    Text("0:42")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
            }
            
            HStack(spacing: 20) {
                // Video Play/Pause button
                if let file = currentFile, file.isVideo {
                    Button(action: { isPlayingVideo.toggle() }) {
                        Image(systemName: isPlayingVideo ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                }
                
                Spacer()
                
                // Security Badge
                SecurityBadge(title: "RAM STREAMING", color: Color(red: 0.2, green: 0.8, blue: 0.6))
                
                Spacer()
                
                // Shred Current File
                Button(action: {
                    if let file = currentFile {
                        vaultVM.deleteFile(file)
                        if vaultVM.activeGalleryFiles.isEmpty {
                            dismiss()
                        } else {
                            vaultVM.activeGalleryIndex = max(0, vaultVM.activeGalleryIndex - 1)
                        }
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Single Gallery Page Item
struct GalleryPageItem: View {
    let file: VaultFile
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @StateObject private var viewerVM: SecureViewerViewModel
    
    init(file: VaultFile, isPlaying: Binding<Bool>, progress: Binding<Double>) {
        self.file = file
        self._isPlaying = isPlaying
        self._progress = progress
        self._viewerVM = StateObject(wrappedValue: SecureViewerViewModel(file: file))
    }
    
    var body: some View {
        ZStack {
            if viewerVM.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                    .scaleEffect(1.4)
            } else if let img = viewerVM.decryptedImage {
                SecureImageViewer(image: img)
            } else if file.isVideo {
                // In-memory Video Player Mock
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.08))
                        .padding(16)
                    
                    VStack(spacing: 16) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .padding(24)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .onTapGesture {
                                isPlaying.toggle()
                            }
                        
                        Text("Encrypted RAM Video Stream")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("Decrypted directly to memory buffers. Zero flash persistence.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: file.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(file.iconColor)
                    Text(file.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}
