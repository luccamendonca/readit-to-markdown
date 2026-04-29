import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Setup") {
                    Text("Open any URL in Safari, tap **Share**, then tap **Readit**. The first time you share, you'll be asked to pick your vault folder. Every share after that saves silently.")
                }
                Section("Why is the picker not here?") {
                    Text("Free Apple ID accounts can't share data between an app and its extension, so the share extension manages its own vault bookmark.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Readit")
        }
    }
}
