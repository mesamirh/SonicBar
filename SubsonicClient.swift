import AppKit
import Foundation
import CryptoKit

struct SubsonicSong: Codable, Identifiable {
    let id: String
    let title: String
    let artist: String?
    let albumId: String?
    let coverArt: String?
    let suffix: String?
    let bitRate: Int?
}

struct SubsonicPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let songCount: Int
    let duration: Int
}

struct SubsonicAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let artist: String?
    let coverArt: String?
}

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    
    func set(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
}

class SubsonicClient: ObservableObject {
    @Published var serverURL = UserDefaults.standard.string(forKey: "SubsonicURL") ?? ""
    @Published var username = UserDefaults.standard.string(forKey: "SubsonicUsername") ?? ""
    @Published var password = UserDefaults.standard.string(forKey: "SubsonicPassword") ?? ""
    
    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "SubsonicURL")
        UserDefaults.standard.set(username, forKey: "SubsonicUsername")
        UserDefaults.standard.set(password, forKey: "SubsonicPassword")
    }
    
    private func generateAuthParams() -> String {
        let salt = String(Int.random(in: 100000...999999))
        let tokenString = password + salt
        let tokenHash = Insecure.MD5.hash(data: tokenString.data(using: .utf8)!).compactMap { String(format: "%02x", $0) }.joined()
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedUser = cleanUsername.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "u=\(encodedUser)&t=\(tokenHash)&s=\(salt)&v=1.16.1&c=SonicBar&f=json"
    }
    
    private func getBaseURL() -> String {
        var base = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.hasSuffix("/") {
            base += "/"
        }
        return "\(base)rest/"
    }
    
    func ping(completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(getBaseURL())ping?\(generateAuthParams())"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion(false, "Invalid URL format") }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(false, "Network error: \(error?.localizedDescription ?? "Unknown error")") }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resp = json["subsonic-response"] as? [String: Any] {
                    if let status = resp["status"] as? String, status == "ok" {
                        DispatchQueue.main.async { completion(true, nil) }
                    } else if let err = resp["error"] as? [String: Any], let msg = err["message"] as? String {
                        DispatchQueue.main.async { completion(false, msg) }
                    } else {
                        DispatchQueue.main.async { completion(false, "API error") }
                    }
                } else {
                    DispatchQueue.main.async { completion(false, "Invalid response") }
                }
            } catch {
                DispatchQueue.main.async { completion(false, "Parse error") }
            }
        }.resume()
    }
    
    func getRandomSongs(count: Int = 20, completion: @escaping ([SubsonicSong]?) -> Void) {
        let urlString = "\(getBaseURL())getRandomSongs?\(generateAuthParams())&size=\(count)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = json["subsonic-response"] as? [String: Any],
                   let randomSongs = response["randomSongs"] as? [String: Any],
                   let songsArray = randomSongs["song"] as? [[String: Any]] {
                    
                    let data = try JSONSerialization.data(withJSONObject: songsArray)
                    let songs = try JSONDecoder().decode([SubsonicSong].self, from: data)
                    DispatchQueue.main.async { completion(songs) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("Failed to decode JSON: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func getStreamURL(for songId: String) -> URL? {
        let urlString = "\(getBaseURL())stream?id=\(songId)&\(generateAuthParams())"
        return URL(string: urlString)
    }
    
    func getCoverArtURL(for coverArtId: String, size: Int = 300) -> URL? {
        let urlString = "\(getBaseURL())getCoverArt?id=\(coverArtId)&size=\(size)&\(generateAuthParams())"
        return URL(string: urlString)
    }
    
    func getPlaylists(completion: @escaping ([SubsonicPlaylist]?) -> Void) {
        let urlString = "\(getBaseURL())getPlaylists?\(generateAuthParams())"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = json["subsonic-response"] as? [String: Any],
                   let playlistsObj = response["playlists"] as? [String: Any],
                   let array = playlistsObj["playlist"] as? [[String: Any]] {
                    
                    let parseData = try JSONSerialization.data(withJSONObject: array)
                    let items = try JSONDecoder().decode([SubsonicPlaylist].self, from: parseData)
                    DispatchQueue.main.async { completion(items) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func getAlbumList(completion: @escaping ([SubsonicAlbum]?) -> Void) {
        let urlString = "\(getBaseURL())getAlbumList2?type=newest&size=30&\(generateAuthParams())"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { DispatchQueue.main.async { completion(nil) }; return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = json["subsonic-response"] as? [String: Any],
                   let listObj = response["albumList2"] as? [String: Any],
                   let array = listObj["album"] as? [[String: Any]] {
                    
                    let parseData = try JSONSerialization.data(withJSONObject: array)
                    let items = try JSONDecoder().decode([SubsonicAlbum].self, from: parseData)
                    DispatchQueue.main.async { completion(items) }
                } else { DispatchQueue.main.async { completion(nil) } }
            } catch { DispatchQueue.main.async { completion(nil) } }
        }.resume()
    }
    
    func getAlbumSongs(id: String, completion: @escaping ([SubsonicSong]?) -> Void) {
        let urlString = "\(getBaseURL())getAlbum?id=\(id)&\(generateAuthParams())"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { DispatchQueue.main.async { completion(nil) }; return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = json["subsonic-response"] as? [String: Any],
                   let albumObj = response["album"] as? [String: Any],
                   let array = albumObj["song"] as? [[String: Any]] {
                    
                    let parseData = try JSONSerialization.data(withJSONObject: array)
                    let items = try JSONDecoder().decode([SubsonicSong].self, from: parseData)
                    DispatchQueue.main.async { completion(items) }
                } else { DispatchQueue.main.async { completion(nil) } }
            } catch { DispatchQueue.main.async { completion(nil) } }
        }.resume()
    }
}
