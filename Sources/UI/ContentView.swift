import SwiftUI

let applePurple = Color(red: 124/255, green: 124/255, blue: 255/255)
let appleBlue = Color(red: 90/255, green: 200/255, blue: 250/255)
let appleRed = Color(red: 255/255, green: 69/255, blue: 58/255)

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var hoverState: HoverState
    
    // Client instances
    @StateObject private var subsonicClient = SubsonicClient()
    @StateObject private var jellyfinClient = JellyfinClient()
    @StateObject private var localClient = LocalMusicClient()
    @State private var selectedServerType: ServerType = .subsonic
    
    // Active client helper
    private var client: any MusicClientProtocol {
        switch selectedServerType {
        case .subsonic: return subsonicClient
        case .jellyfin: return jellyfinClient
        case .local: return localClient
        }
    }
    
    @State private var showSettings = false
    @State private var showPlaylistPopover = false
    @State private var showHiddenMenu = false
    @State private var playlist: [MusicSong] = []
    @State private var currentIndex = 0
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    @State private var isRepeatEnabled = false
    @State private var isShuffleEnabled = true
    
    // Removed internal timer as hover is now event-driven
    
    @FocusState private var focusedField: String?
    
    private var isFormComplete: Bool {
        switch selectedServerType {
        case .subsonic:
            return !subsonicClient.serverURL.isEmpty && !subsonicClient.username.isEmpty && !subsonicClient.password.isEmpty
        case .jellyfin:
            return !jellyfinClient.serverURL.isEmpty && !jellyfinClient.username.isEmpty && !jellyfinClient.password.isEmpty
        case .local:
            return !localClient.serverURL.isEmpty
        }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "ActiveServerType") ?? ServerType.subsonic.rawValue
        _selectedServerType = State(initialValue: ServerType(rawValue: saved) ?? .subsonic)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Glass effect
                RoundedRectangle(cornerRadius: hoverState.isHovered ? 28 : 12, style: .continuous)
                    .fill(Color.black.opacity(hoverState.isHovered ? 0.8 : 0))
                    .background(
                        RoundedRectangle(cornerRadius: hoverState.isHovered ? 28 : 12, style: .continuous)
                            .fill(hoverState.isHovered ? Material.ultraThinMaterial : Material.regularMaterial)
                            .opacity(hoverState.isHovered ? 1.0 : 0.0)
                    )
                    .shadow(color: Color.black.opacity(hoverState.isHovered ? 0.4 : 0), radius: 20, y: 10)
                    .frame(
                        width: hoverState.isHovered ? 360 : 175,
                        height: hoverState.isHovered ? (showSettings || client.serverURL.isEmpty || errorMessage != nil ? 340 : 160) : hoverState.notchHeight
                    )
                    .overlay(
                        VStack(spacing: 0) {
                            if hoverState.isHovered {
                                if !showSettings && !client.serverURL.isEmpty && errorMessage == nil {
                                    Spacer().frame(height: 38)
                                }
                                
                                if client.serverURL.isEmpty || showSettings {
                                    settingsView
                                } else {
                                    playerView
                                }
                            }
                        }
                        .frame(width: 360, height: showSettings || client.serverURL.isEmpty || errorMessage != nil ? 340 : 160)
                        .clipped()
                        .opacity(hoverState.isHovered ? 1.0 : 0.0)
                        .scaleEffect(hoverState.isHovered ? 1.0 : 0.95, anchor: .top)
                    )
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: hoverState.state)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: showSettings)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: errorMessage)
            
            Spacer()
        }
        .frame(width: 420, height: 420)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    if hoverState.isHovered && !client.serverURL.isEmpty {
                        withAnimation { showHiddenMenu = true }
                    }
                }
        )
        .overlay(
            Group {
                if showHiddenMenu {
                    ZStack {
                        Color.black.opacity(0.85).background(Material.ultraThinMaterial)
                        
                        VStack(spacing: 0) {
                            // Header
                            VStack(spacing: 2) {
                                Text("Preferences")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Manage your SonicBar settings")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            
                            // Actions
                            VStack(spacing: 8) {
                                HiddenMenuButton(icon: hoverState.isLockedToNotch ? "lock.fill" : "lock.open.fill", 
                                                 title: hoverState.isLockedToNotch ? "Unlock Position" : "Lock to Notch") {
                                    hoverState.isLockedToNotch.toggle()
                                }
                                
                                HiddenMenuButton(icon: "gearshape.fill", title: "Connection Settings") {
                                    withAnimation { showSettings = true; showHiddenMenu = false }
                                }
                                
                                HiddenMenuButton(icon: "rectangle.portrait.and.arrow.right", title: "Logout / Switch Server") {
                                    logout()
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            Spacer().frame(height: 18)
                            
                            // Danger zone
                            VStack(spacing: 8) {
                                Text("Danger Zone")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 24)
                                
                                HiddenMenuButton(icon: "power", title: "Quit App", isDestructive: true) {
                                    NSApplication.shared.terminate(nil)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(width: 340)
                    .fixedSize(horizontal: false, vertical: true)
                    .cornerRadius(28)
                    .offset(y: 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        )
        .onChange(of: hoverState.state) { _, newState in
            if newState == .hidden {
                showHiddenMenu = false
                showPlaylistPopover = false
                showSettings = client.serverURL.isEmpty
            }
        }
        .onChange(of: showPlaylistPopover) { _, newValue in
            hoverState.state = newValue ? .interacting : .hovered
        }
        .onChange(of: showSettings) { _, newValue in
            if newValue { hoverState.state = .interacting }
            NotificationCenter.default.post(name: NSNotification.Name("ToggleSettingsPosition"), object: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForcePlayCurrent"))) { _ in
            playCurrent()
        }
        .onAppear {
            audioPlayer.onSongEnded = {
                if isRepeatEnabled {
                    audioPlayer.seek(to: 0.0)
                    audioPlayer.togglePlayPause() // ensure keeps playing
                    playCurrent()
                } else {
                    playNext()
                }
            }
            audioPlayer.onNextTrackRequested = { playNext() }
            audioPlayer.onPreviousTrackRequested = { playPrevious() }
            
            if client.serverURL.isEmpty {
                showSettings = true
                // hoverState.state is controlled by NotchTracker, but we can set it here for setup
                hoverState.state = .interacting
            } else if playlist.isEmpty {
                validateAndConnect(silent: true)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var settingsView: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("Connect to your music")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Select your server provider to begin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Server Provider")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.leading, 2)
                
                Picker("", selection: $selectedServerType) {
                    ForEach(ServerType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: selectedServerType) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "ActiveServerType")
                }
            }
            .padding(.horizontal, 28)
            
            VStack(spacing: 10) {
                if selectedServerType == .subsonic {
                    VStack(alignment: .leading, spacing: 6) {
                        GuidedField(label: "Server URL", helper: "Your Subsonic address", placeholder: "https://music.example.com", text: $subsonicClient.serverURL)
                            .focused($focusedField, equals: "url")
                        
                        if let errorMsg = errorMessage {
                            errorDisplay(errorMsg)
                        }
                    }
                    
                    GuidedField(label: "Username", text: $subsonicClient.username)
                        .focused($focusedField, equals: "user")
                    GuidedSecureField(label: "Password", text: $subsonicClient.password)
                        .focused($focusedField, equals: "pass")
                } else if selectedServerType == .jellyfin {
                    VStack(alignment: .leading, spacing: 6) {
                        GuidedField(label: "Server URL", helper: "Your Jellyfin server address", placeholder: "https://jellyfin.example.com", text: $jellyfinClient.serverURL)
                            .focused($focusedField, equals: "url")
                        
                        if let errorMsg = errorMessage {
                            errorDisplay(errorMsg)
                        }
                    }
                    
                    GuidedField(label: "Username", text: $jellyfinClient.username)
                        .focused($focusedField, equals: "user")
                    GuidedSecureField(label: "Password", text: $jellyfinClient.password)
                        .focused($focusedField, equals: "pass")
                } else {
                    // Local directories
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Music Directories")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        
                        VStack(spacing: 6) {
                            let paths = localClient.serverURL.components(separatedBy: ";").filter { !$0.isEmpty }
                            ForEach(paths, id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(appleBlue.opacity(0.8))
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                    Button(action: { removePath(path) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white.opacity(0.2))
                                    }.buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                            }
                            
                            Button(action: { selectFolders() }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Directories")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(appleBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(appleBlue.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let errorMsg = errorMessage {
                            errorDisplay(errorMsg)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)
            
            HStack(spacing: 12) {
                if !client.serverURL.isEmpty && errorMessage == nil {
                    Button(action: { showSettings = false }) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 90, height: 32)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnecting)
                }
                
                Button(action: { validateAndConnect() }) {
                    ZStack {
                        if isConnecting {
                            ProgressView().controlSize(.small).colorInvert()
                        } else {
                            Text("Connect")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isFormComplete ? .black : .black.opacity(0.4))
                        }
                    }
                    .frame(width: 140, height: 32)
                    .background(isFormComplete ? Color.white : Color.white.opacity(0.3))
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(!isFormComplete || isConnecting)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if client.serverURL.isEmpty {
                    focusedField = "url"
                }
            }
        }
    }
    
    private func validateAndConnect(silent: Bool = false) {
        if selectedServerType == .local {
            isConnecting = true
            errorMessage = nil
            localClient.ping { success, error in
                isConnecting = false
                if success {
                    localClient.saveSettings()
                    showSettings = false
                    if !silent { NSSound(named: "Glass")?.play() }
                    NotificationCenter.default.post(name: NSNotification.Name("ConnectedToServer"), object: nil)
                    if playlist.isEmpty { loadRadio() }
                } else {
                    errorMessage = error ?? "No music found in directories"
                }
            }
            return
        }
        
        guard !client.serverURL.isEmpty || selectedServerType == .local else {
            errorMessage = "Required"
            showSettings = true
            hoverState.state = .hovered
            return
        }
        isConnecting = true
        errorMessage = nil
        
        client.ping { success, error in
            isConnecting = false
            if success {
                client.saveSettings()
                showSettings = false
                
                if !silent {
                   NSSound(named: "Glass")?.play()
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("ConnectedToServer"), object: nil)
                
                if playlist.isEmpty { loadRadio() }
            } else {
                errorMessage = error ?? "Can't connect to server"
                showSettings = true
                hoverState.state = .hovered
            }
        }
    }
    
    private func selectFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            let newPaths = panel.urls.map { $0.path }
            var currentPaths = localClient.serverURL.components(separatedBy: ";").filter { !$0.isEmpty }
            for p in newPaths {
                if !currentPaths.contains(p) {
                    currentPaths.append(p)
                }
            }
            localClient.serverURL = currentPaths.joined(separator: ";")
        }
    }
    
    private func removePath(_ path: String) {
        var currentPaths = localClient.serverURL.components(separatedBy: ";").filter { !$0.isEmpty }
        currentPaths.removeAll { $0 == path }
        localClient.serverURL = currentPaths.joined(separator: ";")
    }
    
    @ViewBuilder
    private func errorDisplay(_ msg: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(msg)
        }
        .foregroundColor(appleRed)
        .font(.system(size: 10, weight: .medium))
        .padding(.leading, 2)
    }
    
    private var playerView: some View {
        VStack(spacing: 0) {
            // Player info
            HStack(alignment: .center, spacing: 14) {
                if let artImage = audioPlayer.albumArtImage {
                    Image(nsImage: artImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                        .shadow(color: Color.black.opacity(0.4), radius: 6, y: 3)
                } else {
                    ZStack {
                        Color.white.opacity(0.1)
                        Image(systemName: "music.note").foregroundColor(.white.opacity(0.5)).font(.headline)
                    }
                    .frame(width: 48, height: 48).cornerRadius(6)
                }
                
                // Track details
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayer.currentTrackName ?? "Not Playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: audioPlayer.currentTrackName)
                    
                    let cleanArtist = (audioPlayer.currentArtistName ?? "---").replacingOccurrences(of: "; ", with: ", ")
                    Text(cleanArtist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: audioPlayer.currentArtistName)
                }
                Spacer()
                
                // Visualizer
                VisualizerView(isPlaying: audioPlayer.isPlaying)
                    .frame(width: 14, height: 14)
                    .opacity(audioPlayer.isPlaying ? 1.0 : 0.4)
                
                // Library button
                Button(action: { showPlaylistPopover.toggle() }) {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPlaylistPopover, arrowEdge: .trailing) {
                    LibraryPopoverView(client: client, audioPlayer: audioPlayer, playlist: $playlist, currentIndex: $currentIndex)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 14)
            
            // Progress bar
            HStack(alignment: .center, spacing: 8) {
                Text(audioPlayer.currentTimeString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 32, alignment: .trailing)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                        Capsule().fill(LinearGradient(gradient: Gradient(colors: [applePurple, appleBlue]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geometry.size.width * (audioPlayer.progress.isNaN ? 0 : audioPlayer.progress)), height: 4)
                            .shadow(color: appleBlue.opacity(0.3), radius: 3)
                    }
                    .animation(.linear(duration: 0.5), value: audioPlayer.progress)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        let percent = max(0, min(1, value.location.x / geometry.size.width))
                        audioPlayer.seek(to: Double(percent))
                    })
                }
                .frame(height: 4)
                
                Text(audioPlayer.durationString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 32, alignment: .leading)
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 14)
            
            // Controls
            HStack(spacing: 30) {
                HoverButton(systemName: "shuffle", baseOpacity: isShuffleEnabled ? 1.0 : 0.25, baseColor: isShuffleEnabled ? appleBlue : .white, size: 14, weight: .regular) {
                    isShuffleEnabled.toggle()
                }
                
                HoverButton(systemName: "backward.fill", baseOpacity: 0.8, size: 16, weight: .regular) {
                    playPrevious()
                }
                
                HoverButton(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill", baseOpacity: 1.0, size: 26, weight: .medium) {
                    if audioPlayer.currentTrackName == nil && !playlist.isEmpty {
                        playCurrent()
                    } else {
                        audioPlayer.togglePlayPause()
                    }
                }
                
                HoverButton(systemName: "forward.fill", baseOpacity: 0.8, size: 16, weight: .regular) {
                    playNext()
                }
                
                HoverButton(systemName: "repeat", baseOpacity: isRepeatEnabled ? 1.0 : 0.25, baseColor: isRepeatEnabled ? appleBlue : .white, size: 14, weight: .regular) {
                    isRepeatEnabled.toggle()
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    private func loadRadio() {
        client.getRandomSongs(count: 20) { songs in
            if let songs = songs, !songs.isEmpty {
                self.playlist = songs
                self.currentIndex = 0
                self.playCurrent()
            }
        }
    }
    
    private func playCurrent() {
        guard currentIndex >= 0 && currentIndex < playlist.count else { return }
        let song = playlist[currentIndex]
        guard let streamURL = client.getStreamURL(for: song.id) else { return }
        
        var artURL: URL? = nil
        if let coverArt = song.coverArt {
            artURL = client.getCoverArtURL(for: coverArt, size: 300)
        }
        
        // Buffer next track
        var nextURL: URL? = nil
        if currentIndex + 1 < playlist.count {
            let nextSong = playlist[currentIndex + 1]
            if let nStream = client.getStreamURL(for: nextSong.id) {
                nextURL = nStream
            }
            // Fetch next art early
            if let nextCover = nextSong.coverArt {
                let cacheKey = nextCover
                if ImageCache.shared.get(forKey: cacheKey) == nil {
                    if let nextArtURL = client.getCoverArtURL(for: nextCover, size: 300) {
                        DispatchQueue.global().async {
                            if let data = try? Data(contentsOf: nextArtURL), let image = NSImage(data: data) {
                                ImageCache.shared.set(image, forKey: cacheKey)
                            }
                        }
                    }
                }
            }
        }
        
        audioPlayer.play(url: streamURL, trackName: song.title, artistName: song.artist, artURL: artURL, nextUrl: nextURL)
    }
    
    private func playNext() {
        if currentIndex < playlist.count - 1 {
            currentIndex += 1
            playCurrent()
        } else {
            loadRadio()
        }
    }
    
    private func playPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            playCurrent()
        }
    }

    private func logout() {
        withAnimation {
            client.serverURL = ""
            client.username = ""
            client.password = ""
            client.saveSettings()
            
            playlist.removeAll()
            errorMessage = nil
            
            showSettings = true
            showHiddenMenu = false
            hoverState.state = .interacting
        }
        
        // Wipe Keychain
        KeychainHelper.shared.delete(account: "Password")
        
        NSSound(named: "Glass")?.play()
    }
}

// UI Components
struct HiddenMenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : .white.opacity(0.6))
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.7) : .white.opacity(0.9))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { o in isHovered = o }
    }
}
            
// Input field with label
struct GuidedField: View {
    var label: String
    var helper: String? = nil
    var placeholder: String = ""
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4)) 
                .padding(.leading, 2)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            if let helper = helper {
                Text(helper)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.leading, 2)
                    .padding(.top, 1)
            }
        }
    }
}

struct GuidedSecureField: View {
    var label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 2)
            
            SecureField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// Image with cache support
struct CachedImage: View {
    let url: URL
    var cacheKey: String
    @State private var loadedImage: NSImage?
    @State private var currentCacheKey: String = ""
    
    init(url: URL, cacheKey: String? = nil) {
        self.url = url
        self.cacheKey = cacheKey ?? url.absoluteString
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image).resizable()
            } else {
                Color.white.opacity(0.1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentCacheKey)
        .onAppear { loadImage() }
        .onChange(of: cacheKey) { _, _ in loadImage() }
    }
    
    private func loadImage() {
        guard cacheKey != currentCacheKey else { return }
        if let cached = ImageCache.shared.get(forKey: cacheKey) {
            self.loadedImage = cached
            self.currentCacheKey = cacheKey
            return
        }
        // Keep old image visible during fetch to avoid flicker
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                ImageCache.shared.set(image, forKey: cacheKey)
                DispatchQueue.main.async {
                    self.loadedImage = image
                    self.currentCacheKey = cacheKey
                }
            }
        }
    }
}

// Hover button with transitions
struct HoverButton: View {
    let systemName: String
    var baseOpacity: Double = 1.0
    var baseColor: Color = .white
    let size: CGFloat
    let weight: Font.Weight
    let action: () -> Void
    
    @State private var hovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .foregroundColor(baseColor.opacity(hovered ? 1.0 : baseOpacity))
                .scaleEffect(hovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { o in hovered = o }
    }
}

// Visualizer View
struct VisualizerView: View {
    var isPlaying: Bool
    @State private var heights: [CGFloat] = [0.3, 0.3, 0.3, 0.3]
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.0)
                    .fill(LinearGradient(gradient: Gradient(colors: [applePurple, appleBlue]), startPoint: .top, endPoint: .bottom))
                    .frame(width: 2.5, height: 14 * heights[index])
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.15)) {
                if isPlaying {
                    heights = (0..<4).map { _ in CGFloat.random(in: 0.2...1.0) }
                } else {
                    heights = [0.3, 0.3, 0.3, 0.3]
                }
            }
        }
    }
}

// Library Popover Content Frame
struct LibraryPopoverView: View {
    let client: any MusicClientProtocol
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var playlist: [MusicSong]
    @Binding var currentIndex: Int
    
    @State private var fetchedAlbums: [MusicAlbum] = []
    @State private var selectedAlbum: MusicAlbum?
    @State private var albumSongs: [MusicSong] = []
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let activeAlbum = selectedAlbum {
                // Secondary View: Songs in Album
                HStack {
                    Button(action: { selectedAlbum = nil; albumSongs.removeAll(); errorMessage = nil }) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold)).foregroundColor(appleBlue)
                    }.buttonStyle(.plain)
                    Text(activeAlbum.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                }.padding(.horizontal, 16).padding(.vertical, 12)
                
                Divider().background(Color.white.opacity(0.1))
                
                if isLoading {
                    loadingFrame
                } else if albumSongs.isEmpty && errorMessage == nil {
                    Text("No songs found").font(.system(size: 11)).foregroundColor(.white.opacity(0.5)).frame(width: 220, height: 260)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(albumSongs.enumerated()), id: \.element.id) { index, song in
                                HoverRow(title: song.title) {
                                    playlist = albumSongs
                                    currentIndex = index
                                    // Trigger first playback loop externally
                                    NotificationCenter.default.post(name: NSNotification.Name("ForcePlayCurrent"), object: nil)
                                }
                            }
                        }
                    }.frame(width: 220, height: 260)
                }
                
            } else {
                // Primary View: Albums
                Text("Library")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16).padding(.vertical, 12)
                
                Divider().background(Color.white.opacity(0.1))
                
                if isLoading {
                    loadingFrame
                } else if fetchedAlbums.isEmpty {
                    Text("No albums found").font(.system(size: 11)).foregroundColor(.white.opacity(0.5)).frame(width: 220, height: 260)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(fetchedAlbums, id: \.id) { album in
                                let artUrl = album.coverArt != nil ? client.getCoverArtURL(for: album.coverArt!, size: 48) : nil
                                HoverRow(title: album.name, thumbnailURL: artUrl, thumbnailCacheKey: album.coverArt) { fetchSongs(for: album) }
                            }
                        }
                    }.frame(width: 240, height: 260)
                }
            }
        }
        .background(Color(white: 0.12).opacity(0.95).background(Material.ultraThinMaterial))
        .onAppear {
            if fetchedAlbums.isEmpty {
                isLoading = true
                client.getAlbumList { lists in
                    self.isLoading = false
                    if let lists = lists { self.fetchedAlbums = lists }
                }
            }
        }
    }
    
    private var loadingFrame: some View {
        VStack {
            ProgressView().controlSize(.small)
            Text("Loading...").font(.system(size: 11)).foregroundColor(.white.opacity(0.5)).padding(.top, 6)
        }.frame(width: 220, height: 260)
    }
    
    private func fetchSongs(for album: MusicAlbum) {
        selectedAlbum = album
        isLoading = true
        errorMessage = nil
        client.getAlbumSongs(id: album.id) { songs in
            isLoading = false
            if let songs = songs { self.albumSongs = songs }
            else { errorMessage = "Failed to load songs" }
        }
    }
}

struct HoverRow: View {
    let title: String
    var thumbnailURL: URL? = nil
    var thumbnailCacheKey: String? = nil
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let url = thumbnailURL {
                    CachedImage(url: url, cacheKey: thumbnailCacheKey ?? url.absoluteString)
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.85))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(isHovered ? 0.12 : 0))
                    .padding(.horizontal, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { o in withAnimation(.easeOut(duration: 0.15)) { isHovered = o } }
    }
}
