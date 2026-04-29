import SwiftUI

enum ShareStatus: Equatable {
    case working
    case success(filename: String)
    case failure(message: String)
}

final class ShareStatusModel: ObservableObject {
    @Published var status: ShareStatus = .working
}

struct ShareStatusView: View {
    @ObservedObject var model: ShareStatusModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch model.status {
            case .working:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Saving…")
                    .font(.headline)
                    .foregroundStyle(.secondary)

            case .success(let filename):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.title2.weight(.semibold))
                Text(filename)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

            case .failure(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text("Failed")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .animation(.easeInOut(duration: 0.2), value: model.status)
    }
}
