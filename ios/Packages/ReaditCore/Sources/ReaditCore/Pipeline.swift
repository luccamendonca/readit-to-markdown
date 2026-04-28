import Foundation

public enum DispatchMode: Sendable {
    case html, markdown, plain, other
}

public enum Pipeline {
    /// Mirrors the Go dispatch decision: media type first, with `.md`/`.markdown`
    /// and `.txt` URL extensions overriding for the markdown/plain modes.
    public static func dispatch(contentType: String, url: URL) -> DispatchMode {
        let media = mediaType(from: contentType).lowercased()
        let path = url.path.lowercased()

        if media == "text/markdown" || media == "text/x-markdown"
            || path.hasSuffix(".md") || path.hasSuffix(".markdown") {
            return .markdown
        }
        if media == "text/plain" || path.hasSuffix(".txt") {
            return .plain
        }
        if media == "text/html" || media == "application/xhtml+xml" || media.isEmpty {
            return .html
        }
        return .other
    }

    /// Top-level entry point: fetch + classify + assemble an Article.
    /// HTML mode currently returns a stub body — wire in a Readability + HTML→Markdown
    /// implementation here (see ios/README.md).
    public static func process(url: URL) async -> Article {
        let result: FetchResult
        do {
            result = try await Fetcher.fetch(url)
        } catch {
            return stub(url: url)
        }

        switch dispatch(contentType: result.contentType, url: result.finalURL) {
        case .markdown:
            return processMarkdown(url: url, body: result.body)
        case .plain:
            return processPlain(url: url, body: result.body)
        case .html:
            return processHTML(url: url, body: result.body, finalURL: result.finalURL)
        case .other:
            return stub(url: url)
        }
    }

    static func stub(url: URL) -> Article {
        let title = (url.host ?? "") + url.path
        return Article(title: title, summary: "", date: "", url: url.absoluteString, body: url.absoluteString)
    }

    static func processMarkdown(url: URL, body: Data) -> Article {
        let text = String(decoding: body, as: UTF8.self)
        var title = firstMarkdownHeading(text)
        if title.isEmpty { title = URLParse.titleFromURL(url) }
        return Article(title: title, summary: "", date: "", url: url.absoluteString, body: text)
    }

    static func processPlain(url: URL, body: Data) -> Article {
        let text = String(decoding: body, as: UTF8.self)
        return Article(title: URLParse.titleFromURL(url), summary: "", date: "", url: url.absoluteString, body: text)
    }

    static func processHTML(url: URL, body: Data, finalURL: URL) -> Article {
        // TODO: Wire in a Readability port + HTML→Markdown converter here.
        // Until then, fall back to the same stub shape as `other`.
        return stub(url: url)
    }

    static func firstMarkdownHeading(_ s: String) -> String {
        for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func mediaType(from contentType: String) -> String {
        guard let semi = contentType.firstIndex(of: ";") else {
            return contentType.trimmingCharacters(in: .whitespaces)
        }
        return String(contentType[..<semi]).trimmingCharacters(in: .whitespaces)
    }
}
