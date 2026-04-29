import Foundation
import SwiftSoup

/// First-pass HTML → Markdown converter. Scope matches what Readability's
/// extracted article content typically contains: headings, paragraphs, lists,
/// inline emphasis, links, images, code, and blockquotes. Anything outside
/// that set degrades to its inner text.
public enum HTMLToMarkdown {
    public static func convert(_ html: String) throws -> String {
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = doc.body() ?? doc
        var out = ""
        try renderChildren(root, into: &out)
        return collapseBlankLines(out).trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    // MARK: - Walk

    private static func renderChildren(_ node: Node, into out: inout String) throws {
        for child in node.getChildNodes() {
            try render(child, into: &out)
        }
    }

    private static func render(_ node: Node, into out: inout String) throws {
        if let text = node as? TextNode {
            out += normalizeInlineWhitespace(text.text())
            return
        }
        guard let el = node as? Element else { return }

        switch el.tagName().lowercased() {
        case "h1": try emitHeading(el, level: 1, into: &out)
        case "h2": try emitHeading(el, level: 2, into: &out)
        case "h3": try emitHeading(el, level: 3, into: &out)
        case "h4": try emitHeading(el, level: 4, into: &out)
        case "h5": try emitHeading(el, level: 5, into: &out)
        case "h6": try emitHeading(el, level: 6, into: &out)

        case "p":
            ensureBlankLine(&out)
            try renderChildren(el, into: &out)
            ensureBlankLine(&out)

        case "br":
            out += "  \n"

        case "hr":
            ensureBlankLine(&out)
            out += "---\n\n"

        case "a":
            let href = (try? el.attr("href")) ?? ""
            var inner = ""
            try renderChildren(el, into: &inner)
            let label = inner.isEmpty ? href : inner
            if href.isEmpty {
                out += label
            } else {
                out += "[\(label)](\(href))"
            }

        case "img":
            let src = (try? el.attr("src")) ?? ""
            let alt = (try? el.attr("alt")) ?? ""
            if !src.isEmpty {
                out += "![\(alt)](\(src))"
            }

        case "strong", "b":
            var inner = ""
            try renderChildren(el, into: &inner)
            if !inner.isEmpty { out += "**\(inner)**" }

        case "em", "i":
            var inner = ""
            try renderChildren(el, into: &inner)
            if !inner.isEmpty { out += "*\(inner)*" }

        case "code":
            // Inline code only; <pre><code> is handled by the <pre> branch.
            if el.parent()?.tagName().lowercased() == "pre" {
                try renderChildren(el, into: &out)
            } else {
                let raw = (try? el.text()) ?? ""
                out += "`\(raw)`"
            }

        case "pre":
            ensureBlankLine(&out)
            let raw = (try? el.text()) ?? ""
            out += "```\n"
            out += raw
            if !raw.hasSuffix("\n") { out += "\n" }
            out += "```\n\n"

        case "blockquote":
            ensureBlankLine(&out)
            var inner = ""
            try renderChildren(el, into: &inner)
            let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            for line in trimmed.split(separator: "\n", omittingEmptySubsequences: false) {
                out += "> \(line)\n"
            }
            out += "\n"

        case "ul":
            try emitList(el, ordered: false, into: &out)

        case "ol":
            try emitList(el, ordered: true, into: &out)

        case "li":
            // Stray <li> outside a list — render as a bullet.
            ensureBlankLine(&out)
            out += "- "
            try renderChildren(el, into: &out)
            if !out.hasSuffix("\n") { out += "\n" }

        case "div", "section", "article", "main", "header", "footer", "aside", "figure":
            ensureBlankLine(&out)
            try renderChildren(el, into: &out)
            ensureBlankLine(&out)

        default:
            // Unknown tag: render its children inline.
            try renderChildren(el, into: &out)
        }
    }

    private static func emitHeading(_ el: Element, level: Int, into out: inout String) throws {
        ensureBlankLine(&out)
        var inner = ""
        try renderChildren(el, into: &inner)
        let text = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        out += String(repeating: "#", count: level) + " " + text + "\n\n"
    }

    private static func emitList(_ el: Element, ordered: Bool, into out: inout String) throws {
        ensureBlankLine(&out)
        var index = 1
        for child in el.getChildNodes() {
            guard let li = child as? Element, li.tagName().lowercased() == "li" else { continue }
            var inner = ""
            try renderChildren(li, into: &inner)
            let text = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = ordered ? "\(index). " : "- "
            out += prefix + text + "\n"
            index += 1
        }
        out += "\n"
    }

    // MARK: - Whitespace helpers

    private static func ensureBlankLine(_ out: inout String) {
        if out.isEmpty { return }
        if out.hasSuffix("\n\n") { return }
        if out.hasSuffix("\n") { out += "\n"; return }
        out += "\n\n"
    }

    /// Collapses runs of whitespace (incl. newlines from raw HTML formatting)
    /// down to single spaces. Applied to text nodes, not to <pre> contents.
    private static func normalizeInlineWhitespace(_ s: String) -> String {
        var result = ""
        result.reserveCapacity(s.count)
        var lastWasSpace = false
        for ch in s {
            if ch.isWhitespace {
                if !lastWasSpace {
                    result.append(" ")
                    lastWasSpace = true
                }
            } else {
                result.append(ch)
                lastWasSpace = false
            }
        }
        return result
    }

    private static func collapseBlankLines(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var newlineRun = 0
        for ch in s {
            if ch == "\n" {
                newlineRun += 1
                if newlineRun <= 2 { out.append(ch) }
            } else {
                newlineRun = 0
                out.append(ch)
            }
        }
        return out
    }
}
