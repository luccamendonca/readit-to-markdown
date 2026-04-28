import Foundation

public enum Slug {
    public static func slugify(_ s: String) -> String {
        let lower = s.lowercased()
        var out = ""
        var lastWasDash = false
        for scalar in lower.unicodeScalars {
            let c = Character(scalar)
            let isAlnum = c.isASCII && (c.isLetter || c.isNumber)
            if isAlnum {
                out.append(c)
                lastWasDash = false
            } else if !lastWasDash {
                out.append("-")
                lastWasDash = true
            }
        }
        var trimmed = trimDashes(out)
        if trimmed.utf8.count > 80 {
            let bytes = Array(trimmed.utf8.prefix(80))
            trimmed = String(decoding: bytes, as: UTF8.self)
            trimmed = trimDashes(trimmed)
        }
        return trimmed
    }

    private static func trimDashes(_ s: String) -> String {
        var start = s.startIndex
        var end = s.endIndex
        while start < end, s[start] == "-" { start = s.index(after: start) }
        while end > start, s[s.index(before: end)] == "-" { end = s.index(before: end) }
        return String(s[start..<end])
    }
}
