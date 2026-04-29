import Foundation

/// Persists the user-picked vault folder as a security-scoped bookmark in
/// the caller's UserDefaults. With no App Group available (free Apple ID
/// tier), the share extension stores its own bookmark in its own container.
public struct VaultBookmark {
    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults = .standard, key: String = "vaultBookmark") {
        self.defaults = defaults
        self.key = key
    }

    public func save(_ url: URL) throws {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
    }

    /// Returns the resolved folder URL. Caller is responsible for balancing
    /// `startAccessingSecurityScopedResource()` / `stop...` around any I/O.
    public func resolve() throws -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        let url = try URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            try? save(url)
        }
        return url
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
