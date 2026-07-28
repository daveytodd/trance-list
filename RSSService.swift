import Foundation

// Simple model representing a YouTube video entry
public struct VideoItem: Identifiable {
    public let id: String          // video ID
    public let title: String
    public let published: Date
    public let link: URL
}

// Service that downloads the YouTube RSS feed and parses it
public final class RSSService: NSObject, XMLParserDelegate {
    private let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCalCDsmZayd73tQvz4L8YJg")!
    private var items: [VideoItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentID = ""
    private var currentLink = ""
    private var currentPublished = ""
    private var parsingEntry = false

    // Public method to fetch the feed
    public func fetchVideos(completion: @escaping (Result<[VideoItem], Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: feedURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "RSSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))}
                return
            }
            let parser = XMLParser(data: data)
            parser.delegate = self
            if parser.parse() {
                DispatchQueue.main.async { completion(.success(self.items)) }
            } else {
                let parseError = parser.parserError ?? NSError(domain: "RSSService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unknown XML parsing error"])                
                DispatchQueue.main.async { completion(.failure(parseError)) }
            }
        }
        task.resume()
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "entry" {
            // start a new entry
            parsingEntry = true
            currentTitle = ""
            currentID = ""
            currentLink = ""
            currentPublished = ""
        }
        // The <link> element holds the video URL in its href attribute
        if parsingEntry && elementName == "link", let href = attributeDict["href"], let url = URL(string: href) {
            currentLink = href
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard parsingEntry else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "yt:videoId":
            currentID += string
        case "published":
            currentPublished += string
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            // Finished one entry – create a VideoItem if we have the needed data
            if let videoURL = URL(string: currentLink),
               let pubDate = ISO8601DateFormatter().date(from: currentPublished.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let item = VideoItem(id: currentID.trimmingCharacters(in: .whitespacesAndNewlines),
                                     title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                     published: pubDate,
                                     link: videoURL)
                items.append(item)
            }
            parsingEntry = false
        }
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Propagate parsing errors via the parser’s error property – handled in fetchVideos
    }
}
