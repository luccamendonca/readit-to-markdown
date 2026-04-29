import Foundation
import Readability

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
        let html = String(decoding: body, as: UTF8.self)
        let result: ReadabilityResult
        do {
            let reader = try Readability(html: html, baseURL: finalURL)
            result = try reader.parse()
        } catch {
            return Article(
                title: URLParse.titleFromURL(url),
                summary: "",
                date: "",
                url: url.absoluteString,
                body: url.absoluteString
            )
        }

        if result.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Article(
                title: URLParse.titleFromURL(url),
                summary: "",
                date: "",
                url: url.absoluteString,
                body: url.absoluteString
            )
        }

        var title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = URLParse.titleFromURL(url) }

        let summary = (result.excerpt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parsePublishedDate(result.publishedTime)

        let md: String
        do {
            md = try HTMLToMarkdown.convert(result.content)
        } catch {
            return Article(title: title, summary: summary, date: date, url: url.absoluteString, body: url.absoluteString)
        }
        if md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Article(title: title, summary: summary, date: date, url: url.absoluteString, body: url.absoluteString)
        }
        return Article(title: title, summary: summary, date: date, url: url.absoluteString, body: md)
    }

    /// Mozilla Readability returns publishedTime verbatim from the source's
    /// metadata. Most sites emit ISO 8601, but tolerate a couple of common
    /// fallbacks. On any failure, return "" so the frontmatter writes `null`.
    static func parsePublishedDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return formatYMD(d) }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return formatYMD(d) }
        let alt = DateFormatter()
        alt.locale = Locale(identifier: "en_US_POSIX")
        alt.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            alt.dateFormat = fmt
            if let d = alt.date(from: raw) { return formatYMD(d) }
        }
        return ""
    }

    private static func formatYMD(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
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
