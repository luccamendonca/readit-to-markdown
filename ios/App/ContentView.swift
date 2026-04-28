import SwiftUI
import ReaditCore
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var pickerPresented = false
    @State private var vaultPath: String = "(not set)"
    @State private var statusMessage: String?

    private let bookmark = VaultBookmark(appGroupID: AppConfig.appGroupID)

    var body: some View {
        NavigationStack {
            Form {
                Section("Vault folder") {
                    Text(vaultPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Pick folder…") { pickerPresented = true }
                }
                Section("How to use") {
                    Text("Share any URL from Safari (or any app) and pick **Readit**. The article is fetched, converted to Markdown, and saved into the chosen vault folder.")
                }
                if let statusMessage {
                    Section { Text(statusMessage).font(.footnote) }
                }
            }
            .navigationTitle("Readit")
        }
        .onAppear(perform: refreshVaultPath)
        .fileImporter(
            isPresented: $pickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    try bookmark.save(url)
                    statusMessage = "Saved vault: \(url.path)"
                    refreshVaultPath()
                } catch {
                    statusMessage = "Save failed: \(error.localizedDescription)"
                }
            case .failure(let error):
                statusMessage = "Pick failed: \(error.localizedDescription)"
            }
        }
    }

    private func refreshVaultPath() {
        if let url = (try? bookmark.resolve()) ?? nil {
            vaultPath = url.path
        } else {
            vaultPath = "(not set)"
        }
    }
}
