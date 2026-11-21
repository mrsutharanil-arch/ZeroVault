//
//  VaultHomeView.swift
//  ZeroVault
//
//  Main sovereign vault dashboard. Exclusively accessible by the owner.
//  Provides high-speed encrypted file listing, category filters,
//  fast scrolling timeline scrubber, 3-column grid & list layout switching,
//  date/type grouping, and media gallery swiper.
//

import SwiftUI

public struct VaultHomeView: View {
    @ObservedObject public var vaultVM: VaultViewModel
    @ObservedObject public var appState: AppState
    
    @State private var showingAddMenu: Bool = false
    @State private var fileToShred: VaultFile? = nil
    @State private var showingShredConfirm: Bool = false
    
    public init(vaultVM: VaultViewModel, appState: AppState) {
        self.vaultVM = vaultVM
        self.appState = appState
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.04, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Custom Navigation Bar
                    headerBar
                    
                    ScrollViewReader { scrollProxy in
                        ZStack(alignment: .trailing) {
                            ScrollView {
                                VStack(spacing: 14) {
                                    // Security Storage Metric Card
                                    securityMetricCard
                                    
                                    // Category Filter Chips
                                    categoryScrollView
                                    
                                    // View Options Bar (Grid/List & Grouping selector)
                                    viewOptionsBar
                                    
                                    // Search Bar
                                    searchBar
                                    
                                    // File List or Empty State
                                    if vaultVM.filteredFiles.isEmpty {
                                        emptyVaultView
                                    } else {
                                        groupedMediaContentView
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.bottom, 90) // Bottom bar spacing
                            }
                            
                            // Fast Scroll Scrubber (Timeline scrubber on right)
                            if vaultVM.groupingOption != .none && vaultVM.groupedFiles.count > 1 {
                                FastScrollScrubber(groups: vaultVM.groupedFiles) { targetId in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        scrollProxy.scrollTo(targetId, anchor: .top)
                                    }
                                }
                                .padding(.trailing, 4)
                            }
                        }
                    }
                }
                
                // Floating Bottom Action Bar
                VStack {
                    Spacer()
                    bottomActionBar
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                vaultVM.loadVaultFiles()
            }
            .sheet(isPresented: $showingAddMenu) {
                AddFileMenuSheet(vaultVM: vaultVM)
            }
            .sheet(isPresented: $vaultVM.isShowingAuditSheet) {
                StorageSecurityAuditSheet()
            }
            .sheet(isPresented: $vaultVM.isShowingSettings) {
                SecuritySettingsView(appState: appState, vaultVM: vaultVM)
            }
            .fullScreenCover(item: $vaultVM.activeViewerFile) { file in
                SecureFileViewerContainer(file: file)
            }
            .fullScreenCover(isPresented: $vaultVM.isPresentingGallery) {
                SecureMediaGalleryView(vaultVM: vaultVM)
            }
            .fullScreenCover(isPresented: $vaultVM.isShowingCamera) {
                SecureCameraView(vaultVM: vaultVM)
            }
            .alert(isPresented: $showingShredConfirm) {
                Alert(
                    title: Text("Cryptographic Shredding"),
                    message: Text("This will permanently overwrite the file bytes on disk with random noise and zeroes. It cannot be recovered by any forensic tool."),
                    primaryButton: .destructive(Text("Shred File")) {
                        if let file = fileToShred {
                            vaultVM.deleteFile(file)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZEROVAULT")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.5)
                    
                    Text("ALTEXH • OWNER SOVEREIGN")
                        .font(ZeroVaultFont.cryptoAudit())
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        .tracking(1.5)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Security Audit Button
                Button(action: {
                    vaultVM.isShowingAuditSheet = true
                }) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        .padding(8)
                        .background(Color(white: 0.12))
                        .clipShape(Circle())
                }
                
                // Settings Button
                Button(action: {
                    vaultVM.isShowingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(white: 0.12))
                        .clipShape(Circle())
                }
                
                // Panic Immediate Lock Button
                Button(action: {
                    appState.lockVault()
                }) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.06))
    }
    
    // MARK: - Security Metric Card
    
    private var securityMetricCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SOVEREIGN ENCRYPTED STORAGE")
                        .font(ZeroVaultFont.cryptoAudit())
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(vaultVM.formattedStorageString)
                            .font(ZeroVaultFont.metricNumber())
                            .foregroundColor(.white)
                        
                        Text("(\(vaultVM.totalFileCount) files)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    vaultVM.isShowingAuditSheet = true
                }) {
                    HStack(spacing: 4) {
                        Text("Audit")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.12))
                    .cornerRadius(8)
                }
            }
            
            Divider().background(Color(white: 0.15))
            
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                    Text("Zero Backup")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                    Text("Hidden from Files & Photos")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(white: 0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Category Scroll View
    
    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VaultCategory.allCases) { category in
                    Button(action: {
                        vaultVM.selectedCategory = category
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 12, weight: .bold))
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(vaultVM.selectedCategory == category ? category.accentColor.opacity(0.25) : Color(white: 0.1))
                        .foregroundColor(vaultVM.selectedCategory == category ? category.accentColor : .gray)
                        .cornerRadius(20)
                        .overlay(
                            Capsule()
                                .stroke(vaultVM.selectedCategory == category ? category.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - View Options Bar (Grid/List & Grouping)
    
    private var viewOptionsBar: some View {
        HStack(spacing: 10) {
            // Grouping Selector Menu
            Menu {
                ForEach(GroupingOption.allCases) { opt in
                    Button(action: {
                        vaultVM.groupingOption = opt
                    }) {
                        HStack {
                            Text("Group by \(opt.rawValue)")
                            if vaultVM.groupingOption == opt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 11))
                    Text("Group: \(vaultVM.groupingOption.rawValue)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundColor(Color(white: 0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(white: 0.12))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // View Mode Toggle (Grid vs List)
            HStack(spacing: 2) {
                Button(action: {
                    vaultVM.layoutMode = .grid
                }) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 13))
                        .foregroundColor(vaultVM.layoutMode == .grid ? Color(red: 0.2, green: 0.8, blue: 0.6) : .gray)
                        .padding(6)
                        .background(vaultVM.layoutMode == .grid ? Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.18) : Color.clear)
                        .cornerRadius(6)
                }
                
                Button(action: {
                    vaultVM.layoutMode = .list
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundColor(vaultVM.layoutMode == .list ? Color(red: 0.2, green: 0.8, blue: 0.6) : .gray)
                        .padding(6)
                        .background(vaultVM.layoutMode == .list ? Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.18) : Color.clear)
                        .cornerRadius(6)
                }
            }
            .padding(2)
            .background(Color(white: 0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search encrypted files...", text: $vaultVM.searchQuery)
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            if !vaultVM.searchQuery.isEmpty {
                Button(action: { vaultVM.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Grouped Media Content View
    
    private var groupedMediaContentView: some View {
        LazyVStack(spacing: 18) {
            ForEach(vaultVM.groupedFiles) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Group Header
                    HStack {
                        Text(group.title.uppercased())
                            .font(ZeroVaultFont.groupTitle())
                            .foregroundColor(.white)
                            .tracking(0.5)
                        
                        Spacer()
                        
                        Text(group.subtitle)
                            .font(ZeroVaultFont.monoMeta())
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                    .padding(.horizontal, 16)
                    
                    if vaultVM.layoutMode == .grid {
                        // 3-Column Square Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(group.files) { file in
                                MediaThumbnailView(file: file) {
                                    vaultVM.openFileViewer(file)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        // Full Detailed List
                        LazyVStack(spacing: 8) {
                            ForEach(group.files) { file in
                                VaultFileRow(
                                    file: file,
                                    onSelect: {
                                        vaultVM.openFileViewer(file)
                                    },
                                    onDelete: {
                                        fileToShred = file
                                        showingShredConfirm = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .id(group.id)
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyVaultView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)
            
            ZStack {
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "shield.checkered")
                    .font(.system(size: 38))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
            }
            
            VStack(spacing: 8) {
                Text(vaultVM.isDecoyMode ? "Vault is Empty" : "Fortress Ready")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(vaultVM.isDecoyMode
                     ? "No confidential files found in this vault."
                     : "Files added here are sealed with AES-256-GCM hardware encryption, completely excluded from iCloud & iTunes backups, and invisible to the Files app and Photos.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if !vaultVM.isDecoyMode {
                Button(action: {
                    showingAddMenu = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add First Encrypted File")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Direct Camera Trigger
            Button(action: {
                vaultVM.isShowingCamera = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                    Text("Secure Camera")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(white: 0.12))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
            }
            
            // Add File (+) Button
            Button(action: {
                showingAddMenu = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.shield.fill")
                    Text("Add File")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                .cornerRadius(14)
                .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color(red: 0.04, green: 0.05, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
