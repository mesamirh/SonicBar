import Foundation
import AVFoundation
import AppKit

class LocalMusicClient: MusicClientProtocol {
    @Published var serverURL = "" // Semicolon separated paths
    @Published var username = ""
    @Published var password = ""
    var serverType: ServerType { .local }
    
    private var cachedSongs: [MusicSong] = []
    private var cachedAlbums: [MusicAlbum] = []
    
    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "LocalMusicPaths") ?? ""
        if !serverURL.isEmpty {
            refreshLibrary()
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "LocalMusicPaths")
    }
    
    func ping(completion: @escaping (Bool, String?) -> Void) {
        if serverURL.isEmpty {
            completion(false, "No directories selected")
            return
        }
        refreshLibrary()
        completion(true, nil)
    }
    
    func getRandomSongs(count: Int, completion: @escaping ([MusicSong]?) -> Void) {
        if cachedSongs.isEmpty {
            refreshLibrary()
        }
        let shuffled = cachedSongs.shuffled()
        completion(Array(shuffled.prefix(count)))
    }
    
    func getAlbumList(completion: @escaping ([MusicAlbum]?) -> Void) {
        if cachedAlbums.isEmpty {
            refreshLibrary()
        }
        completion(cachedAlbums)
    }
    
    func getAlbumSongs(id: String, completion: @escaping ([MusicSong]?) -> Void) {
        let songs = cachedSongs.filter { $0.album == id }
        completion(songs)
    }
    
    func getStreamURL(for songId: String) -> URL? {
        // In local client, songId IS the file path
        return URL(fileURLWithPath: songId)
    }
    
    func getCoverArtURL(for coverArtId: String, size: Int) -> URL? {
        // coverArtId is the path to the artwork file or a data URL (handled by ContentView)
        if coverArtId.starts(with: "file://") {
            return URL(string: coverArtId)
        }
        if coverArtId.starts(with: "/") {
            return URL(fileURLWithPath: coverArtId)
        }
        return nil
    }
    
    func refreshLibrary() {
        let paths = serverURL.components(separatedBy: ";").filter { !$0.isEmpty }
        var allSongs: [MusicSong] = []
        var albumsMap: [String: MusicAlbum] = [:]
        
        let fileManager = FileManager.default
        let audioExtensions = ["mp3", "m4a", "wav", "flac", "aac"]
        
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
            
            for case let fileURL as URL in enumerator {
                if audioExtensions.contains(fileURL.pathExtension.lowercased()) {
                    let song = parseMetadata(for: fileURL)
                    allSongs.append(song)
                    
                    if let albumName = song.album {
                        if albumsMap[albumName] == nil {
                            albumsMap[albumName] = MusicAlbum(id: albumName, name: albumName, artist: song.artist, coverArt: song.coverArt)
                        }
                    }
                }
            }
        }
        
        self.cachedSongs = allSongs
        self.cachedAlbums = Array(albumsMap.values).sorted { $0.name < $1.name }
    }
    
    private func parseMetadata(for url: URL) -> MusicSong {
        let asset = AVURLAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album: String? = nil
        var duration: Int? = nil
        var coverArtPath: String? = nil
        
        // Use modern async API for metadata loading (macOS 13+)
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                let dur = try await asset.load(.duration)
                duration = Int(CMTimeGetSeconds(dur))
                
                let metadata = try await asset.load(.metadata)
                
                for item in metadata {
                    guard let key = item.commonKey else { continue }
                    
                    switch key {
                    case .commonKeyTitle:
                        if let val = try? await item.load(.stringValue) { title = val }
                    case .commonKeyArtist:
                        if let val = try? await item.load(.stringValue) { artist = val }
                    case .commonKeyAlbumName:
                        album = try? await item.load(.stringValue)
                    case .commonKeyArtwork:
                        if let data = try? await item.load(.dataValue) {
                            coverArtPath = self.saveToCache(data: data, for: url)
                        }
                    default: break
                    }
                }
                
                // Fallback artwork check
                if coverArtPath == nil {
                    let artworkItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
                    if let firstArt = artworkItems.first {
                        if let data = try? await firstArt.load(.dataValue) {
                            coverArtPath = self.saveToCache(data: data, for: url)
                        }
                    }
                }
            } catch {
                // Fallback: use filename as title
            }
            semaphore.signal()
        }
        
        // Wait with timeout to avoid blocking forever
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        // If no embedded art found, look for external cover files
        if coverArtPath == nil {
            let folderURL = url.deletingLastPathComponent()
            let possibleArt = ["cover.jpg", "cover.png", "folder.jpg", "AlbumArt.jpg"]
            for artName in possibleArt {
                let artURL = folderURL.appendingPathComponent(artName)
                if FileManager.default.fileExists(atPath: artURL.path) {
                    coverArtPath = artURL.path
                    break
                }
            }
        }
        
        if album == nil {
            album = url.deletingLastPathComponent().lastPathComponent
        }
        
        return MusicSong(
            id: url.path,
            title: title,
            artist: artist,
            album: album,
            coverArt: coverArtPath,
            duration: duration
        )
    }
    
    private func saveToCache(data: Data, for url: URL) -> String? {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("SonicBarCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let filename = url.path.hashValue.description + ".jpg"
        let cachePath = cacheDir.appendingPathComponent(filename)
        
        if !FileManager.default.fileExists(atPath: cachePath.path) {
            try? data.write(to: cachePath)
        }
        return cachePath.path
    }
}
