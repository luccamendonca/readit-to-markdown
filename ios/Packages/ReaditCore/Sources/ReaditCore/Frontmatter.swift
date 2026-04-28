import Foundation

public struct Article: Sendable {
    public var title: String
    public var summary: String
    public var date: String
    public var url: String
    public var body: String

    public init(title: String, summary: String, date: String, url: String, body: String) {
        self.title = title
        self.summary = summary
        self.date = date
        self.url = url
        self.body = body
    }
}

public enum Frontmatter {
    public static func yamlEscape(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "\\", with: "\\\\")
        out = out.replacingOccurrences(of: "\"", with: "\\\"")
        out = out.replacingOccurrences(of: "\n", with: " ")
        return out
    }

    public static func build(_ article: Article, readTime: Int) -> String {
        var out = "---\n"
        out += "title: \"\(yamlEscape(article.title))\"\n"
        if article.summary.isEmpty {
            out += "summary: \"\"\n"
        } else {
            out += "summary: \"\(yamlEscape(article.summary))\"\n"
        }
        if article.date.isEmpty {
            out += "date: null\n"
        } else {
            out += "date: \(article.date)\n"
        }
        out += "url: \(article.url)\n"
        out += "read_time: \(readTime)\n"
        out += "---\n"
        out += article.body
        if !article.body.hasSuffix("\n") {
            out += "\n"
        }
        return out
    }
}
