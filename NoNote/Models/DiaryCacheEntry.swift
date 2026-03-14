import Foundation

struct DiaryCacheEntry: Codable {
    var text: String
    var mood: String?
    var weather: String?
    var photoFileURLs: [URL] = []
    var needsUpload: Bool = false

    private enum CodingKeys: String, CodingKey {
        case text, mood, weather, needsUpload
    }
}
