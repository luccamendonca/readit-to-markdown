import Foundation

/// Persists the user-picked vault folder as a security-scoped bookmark inside
/// the shared App Group's UserDefaults so both the app and the share
/// extension can resolve and write to it.
public struct VaultBookmark {
    public let appGroupID: String
    public let key: String

    public init(appGroupID: String, key: String = "vaultBookmark") {
        self.appGroupID = appGroupID
        self.key = key
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public func save(_ url: URL) throws {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults?.set(data, forKey: key)
    }

    /// Returns the resolved folder URL. Caller is responsible for balancing
    /// `startAccessingSecurityScopedResource()` / `stop...` around any I/O.
    public func resolve() throws -> URL? {
        guard let data = defaults?.data(forKey: key) else { return nil }
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
        defaults?.removeObject(forKey: key)
    }
}
