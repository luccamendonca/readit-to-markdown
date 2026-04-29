import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ReaditCore

/// Entry point for the system share sheet. Embeds a SwiftUI status view,
/// extracts a URL from the input items, runs the ReaditCore pipeline,
/// writes the resulting Markdown into the user-picked vault folder, and
/// dismisses (auto on success, user-driven on failure).
final class ShareViewController: UIViewController {
    private let appGroupID = "group.com.luccamendonca.readit"
    private let model = ShareStatusModel()
    private var hasFinished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        installStatusView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await run() }
    }

    private func installStatusView() {
        let host = UIHostingController(
            rootView: ShareStatusView(
                model: model,
                onDismiss: { [weak self] in self?.complete() }
            )
        )
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func run() async {
        guard let url = await extractURL() else {
            return setStatus(.failure(message: "No URL in shared item."))
        }

        let bookmark = VaultBookmark(appGroupID: appGroupID)
        let folder: URL?
        do {
            folder = try bookmark.resolve()
        } catch {
            return setStatus(.failure(message: "Vault unavailable: \(error.localizedDescription)"))
        }
        guard let folder else {
            return setStatus(.failure(message: "Open Readit and pick a vault folder first."))
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
            setStatus(.success(filename: filename))
            await autoDismiss()
        } catch {
            setStatus(.failure(message: "Write failed: \(error.localizedDescription)"))
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

    private func setStatus(_ status: ShareStatus) {
        Task { @MainActor in self.model.status = status }
    }

    private func autoDismiss() async {
        try? await Task.sleep(nanoseconds: 1_400_000_000)
        complete()
    }

    private func complete() {
        guard !hasFinished else { return }
        hasFinished = true
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
