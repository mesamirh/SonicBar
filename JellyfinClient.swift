import Foundation
import SwiftUI

class JellyfinClient: MusicClientProtocol {
    @Published var serverURL = UserDefaults.standard.string(forKey: "JellyfinURL") ?? ""
    @Published var username = UserDefaults.standard.string(forKey: "JellyfinUsername") ?? ""
    @Published var password = KeychainHelper.shared.read(account: "JellyfinPassword") ?? ""
    
    @Published var accessToken = UserDefaults.standard.string(forKey: "JellyfinToken") ?? ""
    @Published var userId = UserDefaults.standard.string(forKey: "JellyfinUserId") ?? ""
    
    var serverType: ServerType { .jellyfin }
    
    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "JellyfinURL")
        UserDefaults.standard.set(username, forKey: "JellyfinUsername")
        KeychainHelper.shared.save(password, account: "JellyfinPassword")
        UserDefaults.standard.set(accessToken, forKey: "JellyfinToken")
        UserDefaults.standard.set(userId, forKey: "JellyfinUserId")
    }
    
    private func getBaseURL() -> String {
        var base = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.hasSuffix("/") {
            base += "/"
        }
        return base
    }
    
    private func getAuthHeader() -> String {
        return "MediaBrowser Client=\"SonicBar\", Device=\"Mac\", DeviceId=\"SonicBar-v1\", Version=\"1.0.0\""
    }
    
    func ping(completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(getBaseURL())Users/AuthenticateByName"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(getAuthHeader(), forHTTPHeaderField: "X-Emby-Authorization")
        
        let body: [String: String] = ["Username": username, "Pw": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(false, error?.localizedDescription ?? "Connection failed") }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["AccessToken"] as? String,
               let uId = json["User"] as? [String: Any],
               let id = uId["Id"] as? String {
                DispatchQueue.main.async {
                    self.accessToken = token
                    self.userId = id
                    self.saveSettings()
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async { completion(false, "Authentication failed") }
            }
        }.resume()
    }
    
    func getRandomSongs(count: Int = 20, completion: @escaping ([MusicSong]?) -> Void) {
        let urlString = "\(getBaseURL())Items?IncludeItemTypes=Audio&Recursive=true&SortBy=Random&Limit=\(count)&UserId=\(userId)"
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        var request = URLRequest(url: url)
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["Items"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let songs = items.map { item -> MusicSong in
                let artist = (item["Artists"] as? [String])?.first ?? "Unknown"
                let album = item["Album"] as? String
                return MusicSong(
                    id: item["Id"] as? String ?? "",
                    title: item["Name"] as? String ?? "Unknown",
                    artist: artist,
                    album: album,
                    coverArt: item["Id"] as? String, // Use ID as coverArt identifier for Jellyfin
                    duration: (item["RunTimeTicks"] as? Int).map { $0 / 10_000_000 }
                )
            }
            DispatchQueue.main.async { completion(songs) }
        }.resume()
    }
    
    func getAlbumList(completion: @escaping ([MusicAlbum]?) -> Void) {
        let urlString = "\(getBaseURL())Items?IncludeItemTypes=MusicAlbum&Recursive=true&SortBy=DateCreated&SortOrder=Descending&Limit=30&UserId=\(userId)"
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        var request = URLRequest(url: url)
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["Items"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let albums = items.map { item -> MusicAlbum in
                MusicAlbum(
                    id: item["Id"] as? String ?? "",
                    name: item["Name"] as? String ?? "Unknown",
                    artist: (item["Artists"] as? [String])?.first,
                    coverArt: item["Id"] as? String
                )
            }
            DispatchQueue.main.async { completion(albums) }
        }.resume()
    }
    
    func getAlbumSongs(id: String, completion: @escaping ([MusicSong]?) -> Void) {
        let urlString = "\(getBaseURL())Items?ParentId=\(id)&SortBy=SortName&UserId=\(userId)"
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        var request = URLRequest(url: url)
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["Items"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let songs = items.map { item -> MusicSong in
                MusicSong(
                    id: item["Id"] as? String ?? "",
                    title: item["Name"] as? String ?? "Unknown",
                    artist: (item["Artists"] as? [String])?.first ?? "Unknown",
                    album: item["Album"] as? String,
                    coverArt: item["Id"] as? String,
                    duration: (item["RunTimeTicks"] as? Int).map { $0 / 10_000_000 }
                )
            }
            DispatchQueue.main.async { completion(songs) }
        }.resume()
    }
    
    func getStreamURL(for songId: String) -> URL? {
        let urlString = "\(getBaseURL())Audio/\(songId)/stream?static=true&X-Emby-Token=\(accessToken)"
        return URL(string: urlString)
    }
    
    func getCoverArtURL(for coverArtId: String, size: Int = 300) -> URL? {
        let urlString = "\(getBaseURL())Items/\(coverArtId)/Images/Primary?maxWidth=\(size)&X-Emby-Token=\(accessToken)"
        return URL(string: urlString)
    }
}
