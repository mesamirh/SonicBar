import SwiftUI

let applePurple = Color(red: 124/255, green: 124/255, blue: 255/255)
let appleBlue = Color(red: 90/255, green: 200/255, blue: 250/255)
let appleRed = Color(red: 255/255, green: 69/255, blue: 58/255)

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @StateObject private var client = SubsonicClient()
    @State private var showSettings = false
    @State private var showPlaylistPopover = false
    @State private var showHiddenMenu = false
    @State private var playlist: [SubsonicSong] = []
    @State private var currentIndex = 0
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    @State private var isRepeatEnabled = false
    @State private var isShuffleEnabled = true
    
    @State private var isHovered = false
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background glass effect
                RoundedRectangle(cornerRadius: isHovered ? 28 : 12, style: .continuous)
                    .fill(Color.black.opacity(isHovered ? 0.8 : 0))
                    .background(
                        RoundedRectangle(cornerRadius: isHovered ? 28 : 12, style: .continuous)
                            .fill(isHovered ? Material.ultraThinMaterial : Material.regularMaterial)
                            .opacity(isHovered ? 1.0 : 0.0)
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.4 : 0), radius: 20, y: 10)
                    .frame(
                        width: isHovered ? 360 : 175,
                        height: isHovered ? (showSettings || errorMessage != nil ? 340 : 160) : 32
                    )
                    .overlay(
                        VStack(spacing: 0) {
                            Spacer().frame(height: 38)
                            if client.serverURL.isEmpty || showSettings {
                                settingsView
                            } else {
                                playerView
                            }
                        }
                        .frame(width: 360, height: showSettings || errorMessage != nil ? 340 : 160)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .scaleEffect(isHovered ? 1.0 : 0.95, anchor: .top)
                    )
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isHovered)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: showSettings)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: errorMessage)
            
            Spacer()
        }
        .frame(width: 420, height: 420)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    if isHovered && !client.serverURL.isEmpty {
                        withAnimation { showHiddenMenu = true }
                    }
                }
        )
        .overlay(
            Group {
                if showHiddenMenu {
                    ZStack {
                        Color.black.opacity(0.85).background(Material.ultraThinMaterial)
                        HStack(spacing: 40) {
                            Button(action: { withAnimation { showSettings = true; showHiddenMenu = false } }) {
                                VStack { Image(systemName: "gearshape.fill"); Text("Settings").font(.caption) }
                            }
                            Button(action: { NSApplication.shared.terminate(nil) }) {
                                VStack { Image(systemName: "power"); Text("Quit").font(.caption) }.foregroundColor(.red)
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: 360, height: 160).cornerRadius(28).offset(y: -130).transition(.opacity)
                }
            }
        )
        .onReceive(timer) { _ in
            let loc = NSEvent.mouseLocation
            if let screen = NSScreen.main?.frame {
                let triggerRect = NSRect(x: screen.midX - 105, y: screen.maxY - 35, width: 210, height: 35)
                let expandedRect = NSRect(x: screen.midX - 200, y: screen.maxY - 360, width: 400, height: 360)
                
                let shouldHover = (!isHovered && triggerRect.contains(loc)) || (isHovered && expandedRect.contains(loc)) || showPlaylistPopover
                
                if shouldHover != isHovered {
                    isHovered = shouldHover
                    if !shouldHover {
                        showHiddenMenu = false
                        showPlaylistPopover = false
                    }
                    if let window = NSApplication.shared.windows.first {
                        window.ignoresMouseEvents = !shouldHover
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForcePlayCurrent"))) { _ in
            playCurrentSong()
        }
        .onAppear {
            audioPlayer.onSongEnded = {
                if isRepeatEnabled {
                    audioPlayer.seek(to: 0.0)
                    audioPlayer.togglePlayPause() // ensure keeps playing
                } else {
                    playNext()
                }
            }
            audioPlayer.onNextTrackRequested = { playNext() }
            audioPlayer.onPreviousTrackRequested = { playPrevious() }
            
            if client.serverURL.isEmpty {
                showSettings = true
            } else if playlist.isEmpty {
                validateAndConnect()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var settingsView: some View {
        VStack(spacing: 8) {
            Text("Sign in to Navidrome")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            if let errorMsg = errorMessage {
                Text(errorMsg)
                    .foregroundColor(appleRed)
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 6) {
                CustomTextField(placeholder: "Server URL (https://...)", text: $client.serverURL)
                CustomTextField(placeholder: "Username", text: $client.username)
                CustomSecureField(placeholder: "Password", text: $client.password)
            }
            .padding(.bottom, 6)
            
            HStack(spacing: 12) {
                if !client.serverURL.isEmpty && errorMessage == nil {
                    Button(action: { showSettings = false }) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 80, height: 26)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                if isConnecting {
                    ProgressView().controlSize(.small).frame(width: 80, height: 26)
                } else {
                    Button(action: { validateAndConnect() }) {
                        Text("Connect")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 80, height: 26)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }
    
    private func validateAndConnect() {
        guard !client.serverURL.isEmpty, !client.username.isEmpty else {
            errorMessage = "Required"
            showSettings = true
            return
        }
        isConnecting = true
        errorMessage = nil
        
        client.ping { success, error in
            isConnecting = false
            if success {
                client.saveSettings()
                showSettings = false
                if playlist.isEmpty { loadRadio() }
            } else {
                errorMessage = error ?? "Can't connect to server"
                showSettings = true
            }
        }
    }
    
    private var playerView: some View {
        VStack(spacing: 0) {
            // Main Player
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
            
            // Progress Unit 
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
            
            // Playback controls
            HStack(spacing: 30) {
                HoverButton(systemName: "shuffle", baseOpacity: isShuffleEnabled ? 1.0 : 0.25, baseColor: isShuffleEnabled ? appleBlue : .white, size: 14, weight: .regular) {
                    isShuffleEnabled.toggle()
                }
                
                HoverButton(systemName: "backward.fill", baseOpacity: 0.8, size: 16, weight: .regular) {
                    playPrevious()
                }
                
                HoverButton(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill", baseOpacity: 1.0, size: 26, weight: .medium) {
                    if audioPlayer.currentTrackName == nil && !playlist.isEmpty {
                        playCurrentSong()
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
                self.playCurrentSong()
            }
        }
    }
    
    private func playCurrentSong() {
        guard currentIndex >= 0 && currentIndex < playlist.count else { return }
        let song = playlist[currentIndex]
        guard let streamURL = client.getStreamURL(for: song.id) else { return }
        
        var artURL: URL? = nil
        if let coverArt = song.coverArt {
            artURL = client.getCoverArtURL(for: coverArt)
        }
        
        // Preload next track
        var nextURL: URL? = nil
        if currentIndex + 1 < playlist.count {
            let nextSong = playlist[currentIndex + 1]
            if let nStream = client.getStreamURL(for: nextSong.id) {
                nextURL = nStream
            }
            // Early fetch for next art
            if let nextCover = nextSong.coverArt {
                let cacheKey = nextCover
                if ImageCache.shared.get(forKey: cacheKey) == nil {
                    if let nextArtURL = client.getCoverArtURL(for: nextCover) {
                        DispatchQueue.global().async {
                            if let data = try? Data(contentsOf: nextArtURL), let image = NSImage(data: data) {
                                ImageCache.shared.set(image, forKey: cacheKey)
                            }
                        }
                    }
                }
            }
        }
        
        audioPlayer.play(url: streamURL, trackName: song.title, artistName: song.artist ?? "Unknown", artURL: artURL, nextUrl: nextURL)
    }
    
    private func playNext() {
        if currentIndex < playlist.count - 1 {
            currentIndex += 1
            playCurrentSong()
        } else {
            loadRadio()
        }
    }
    
    private func playPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            playCurrentSong()
        }
    }
}

// Custom UI Inputs for Settings View
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    var body: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

// Memory Cached Async Image Support
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
        .onChange(of: cacheKey) { _ in loadImage() }
    }
    
    private func loadImage() {
        guard cacheKey != currentCacheKey else { return }
        if let cached = ImageCache.shared.get(forKey: cacheKey) {
            self.loadedImage = cached
            self.currentCacheKey = cacheKey
            return
        }
        // Keep old image visible while fetching — no nil flash
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
    @ObservedObject var client: SubsonicClient
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var playlist: [SubsonicSong]
    @Binding var currentIndex: Int
    
    @State private var fetchedAlbums: [SubsonicAlbum] = []
    @State private var selectedAlbum: SubsonicAlbum?
    @State private var albumSongs: [SubsonicSong] = []
    
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
    
    private func fetchSongs(for album: SubsonicAlbum) {
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
