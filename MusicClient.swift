import Foundation
import SwiftUI

enum ServerType: String, Codable, CaseIterable {
    case subsonic = "Subsonic"
    case jellyfin = "Jellyfin"
    case local = "Local Music"
}

struct MusicSong: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let coverArt: String?
    let duration: Int?
}

struct MusicAlbum: Identifiable, Codable {
    let id: String
    let name: String
    let artist: String?
    let coverArt: String?
}

protocol MusicClientProtocol: ObservableObject {
    var serverURL: String { get set }
    var username: String { get set }
    var password: String { get set }
    var serverType: ServerType { get }
    
    func saveSettings()
    func ping(completion: @escaping (Bool, String?) -> Void)
    func getRandomSongs(count: Int, completion: @escaping ([MusicSong]?) -> Void)
    func getAlbumList(completion: @escaping ([MusicAlbum]?) -> Void)
    func getAlbumSongs(id: String, completion: @escaping ([MusicSong]?) -> Void)
    func getStreamURL(for songId: String) -> URL?
    func getCoverArtURL(for coverArtId: String, size: Int) -> URL?
}
