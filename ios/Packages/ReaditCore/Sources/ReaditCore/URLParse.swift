import Foundation

public enum URLParse {
    /// Parses a string into a URL only if it has an http(s) scheme and a host.
    /// Mirrors the Go `parseURL` helper's tolerance.
    public static func httpURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    /// Last path segment without extension, falling back to host.
    public static func titleFromURL(_ url: URL) -> String {
        let last = url.lastPathComponent
        let stem = (last as NSString).deletingPathExtension
        if stem.isEmpty || stem == "." || stem == "/" {
            return url.host ?? ""
        }
        return stem
    }
}
