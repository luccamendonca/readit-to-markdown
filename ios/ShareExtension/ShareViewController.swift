import UIKit
import UniformTypeIdentifiers
import ReaditCore

/// Entry point for the system share sheet. Extracts a URL from the input
/// items, runs the ReaditCore pipeline, writes the resulting Markdown into
/// the user-picked vault folder, and dismisses.
final class ShareViewController: UIViewController {
    private let appGroupID = "group.com.luccamendonca.readit"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await run() }
    }

    private func run() async {
        guard let url = await extractURL() else {
            return finish(error: "No URL in shared item")
        }
        let bookmark = VaultBookmark(appGroupID: appGroupID)
        let folder: URL?
        do {
            folder = try bookmark.resolve()
        } catch {
            return finish(error: "Vault unavailable: \(error.localizedDescription)")
        }
        guard let folder else {
            return finish(error: "Open Readit and pick a vault folder first")
        }

        let article = await Pipeline.process(url: url)
        let readTime = ReadTime.minutes(body: article.body)
        let content = Frontmatter.build(article, readTime: readTime)
        let filename = Filename.build(title: article.title, date: Date())

        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let target = folder.appendingPathComponent(filename)
        do {
            try content.data(using: .utf8)?.write(to: target, options: .atomic)
            finish(success: filename)
        } catch {
            finish(error: "Write failed: \(error.localizedDescription)")
        }
    }

    private func extractURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let result = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = result as? URL {
                        return url
                    }
                }
            }
        }
        return nil
    }

    private func finish(success filename: String) {
        // TODO: brief confirmation UI before dismissing.
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func finish(error message: String) {
        // TODO: error UI; for now log and dismiss.
        NSLog("Readit share extension: %@", message)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
