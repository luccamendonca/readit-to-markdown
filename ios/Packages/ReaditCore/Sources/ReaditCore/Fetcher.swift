import Foundation

public struct FetchResult: Sendable {
    public let body: Data
    public let contentType: String
    public let finalURL: URL
}

public enum FetchError: Error, Sendable {
    case http(Int)
    case transport(String)
}

public enum Fetcher {
    public static let userAgent = "readit/1.0 (+https://github.com/luccamendonca/readit-to-markdown)"
    public static let acceptHeader = "text/markdown, text/html;q=0.9, text/plain;q=0.8, */*;q=0.5"
    public static let bodyCap = 20 * 1024 * 1024
    public static let timeout: TimeInterval = 30

    public static func fetch(_ url: URL) async throws -> FetchResult {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")

        let session = URLSession(configuration: .ephemeral)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FetchError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw FetchError.transport("non-http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(http.statusCode)
        }
        let capped = data.count > bodyCap ? data.prefix(bodyCap) : data
        return FetchResult(
            body: Data(capped),
            contentType: http.value(forHTTPHeaderField: "Content-Type") ?? "",
            finalURL: http.url ?? url
        )
    }
}
