import SwiftUI
import AVFoundation
import MediaPlayer

class AudioPlayer: ObservableObject {
    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    
    @Published var isPlaying = false
    @Published var currentTrackName: String?
    @Published var currentArtistName: String?
    @Published var albumArtURL: URL? {
        didSet {
            loadAlbumArtImage()
            updateNowPlayingInfo()
        }
    }
    @Published var albumArtImage: NSImage?
    @Published var progress: Double = 0.0
    
    @Published var currentTimeString: String = "0:00"
    @Published var durationString: String = "0:00"
    
    var onSongEnded: (() -> Void)?
    var onNextTrackRequested: (() -> Void)?
    var onPreviousTrackRequested: (() -> Void)?
    
    init() {
        setupRemoteCommandCenter()
    }
    
    func play(url: URL, trackName: String, artistName: String, artURL: URL?, nextUrl: URL? = nil) {
        
        // Check if this track is already preloaded
        if let player = player, let currentItems = player.items() as [AVPlayerItem]?, currentItems.count > 1 {
            let requestedId = getQueryStringParameter(url: url.absoluteString, param: "id")
            let preloadedUrl = (currentItems[1].asset as? AVURLAsset)?.url
            let queuedId = preloadedUrl != nil ? getQueryStringParameter(url: preloadedUrl!.absoluteString, param: "id") : nil
            
            if requestedId != nil && requestedId == queuedId {
                // Already in queue, just advance
                player.advanceToNextItem()
                
                // Add next track to queue
                if let next = nextUrl {
                    let nextItem = AVPlayerItem(url: next)
                    if player.canInsert(nextItem, after: player.currentItem) {
                        player.insert(nextItem, after: player.currentItem)
                    }
                }
                
                self.finishPlayBinding(trackName: trackName, artistName: artistName, artURL: artURL)
                return
            }
        }
        
        // Rebuild queue if track isn't preloaded
        let playerItem = AVPlayerItem(url: url)
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        if player == nil {
            player = AVQueuePlayer(playerItem: playerItem)
        } else {
            player?.removeAllItems()
            if player?.canInsert(playerItem, after: nil) == true {
                player?.insert(playerItem, after: nil)
            }
        }
        
        // Buffer initialization for next track
        if let next = nextUrl {
            let nextItem = AVPlayerItem(url: next)
            if player?.canInsert(nextItem, after: playerItem) == true {
                player?.insert(nextItem, after: playerItem)
            }
        }
        
        player?.play()
        self.finishPlayBinding(trackName: trackName, artistName: artistName, artURL: artURL)
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let item = self.player?.currentItem else { return }
            
            let current = time.seconds
            if current.isFinite && !current.isNaN {
                let cmins = Int(current) / 60
                let csecs = Int(current) % 60
                self.currentTimeString = String(format: "%d:%02d", cmins, csecs)
            }
            
            let duration = item.duration.seconds
            if duration.isFinite && !duration.isNaN && duration > 0 {
                self.progress = current / duration
                let dmins = Int(duration) / 60
                let dsecs = Int(duration) % 60
                self.durationString = String(format: "%d:%02d", dmins, dsecs)
            } else {
                self.durationString = "0:00"
                self.progress = 0.0
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.isPlaying = false
            self?.progress = 0.0
            self?.onSongEnded?()
        }
    }
    
    private func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
    private func finishPlayBinding(trackName: String, artistName: String, artURL: URL?) {
        isPlaying = true
        self.currentTrackName = trackName
        self.currentArtistName = artistName
        self.progress = 0.0
        self.currentTimeString = "0:00"
        self.durationString = "0:00"
        self.albumArtURL = artURL
        updateNowPlayingInfo()
    }
    
    private func loadAlbumArtImage() {
        guard let url = albumArtURL else {
            self.albumArtImage = nil
            return
        }
        // Extract stable cache key from the cover art id parameter
        let cacheKey = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value ?? url.absoluteString
        
        // Check memory cache first — instant
        if let cached = ImageCache.shared.get(forKey: cacheKey) {
            self.albumArtImage = cached
            return
        }
        // Fetch in background, update on main
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                ImageCache.shared.set(image, forKey: cacheKey)
                DispatchQueue.main.async {
                    // Verify URL hasn't changed during fetch
                    if self?.albumArtURL == url {
                        self?.albumArtImage = image
                    }
                }
            }
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            if self?.player?.rate == 0.0 {
                self?.player?.play()
                self?.isPlaying = true
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            if self?.player?.rate != 0.0 {
                self?.player?.pause()
                self?.isPlaying = false
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNextTrackRequested?()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPreviousTrackRequested?()
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrackName ?? "Unknown"
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentArtistName ?? "Unknown"
        
        if let duration = player?.currentItem?.duration.seconds, duration.isFinite {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds ?? 0
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let url = albumArtURL {
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: url), let nsImage = NSImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in return nsImage }
                    DispatchQueue.main.async {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }
    
    func seek(to percentage: Double) {
        guard let player = player, let item = player.currentItem else { return }
        let duration = item.duration.seconds
        if duration.isFinite && duration > 0 {
            player.seek(to: CMTime(seconds: duration * percentage, preferredTimescale: 600))
        }
    }
    
    func skip(seconds: Double) {
        guard let player = player else { return }
        player.seek(to: CMTime(seconds: player.currentTime().seconds + seconds, preferredTimescale: 600))
    }
    
    func stop() {
        player?.pause()
        isPlaying = false
    }
}
