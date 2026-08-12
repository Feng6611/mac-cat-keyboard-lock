import KikiSettings
import SwiftUI

/// A quiet, optional support card for the About pane. Support never changes
/// Cat Lock's free feature set.
struct CatKeyboardLockSupportCard: View {
    let tint: Color
    let onStar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                Text("Like Cat Lock?")
                    .font(.headline)

                Spacer(minLength: 0)
            }

            Text("Cat Lock is free and complete. Star the project on GitHub to support its development.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Star on GitHub", action: onStar)
                .buttonStyle(.borderedProminent)
                .tint(tint)
        }
        .padding(.vertical, 8)
    }
}

enum CatKeyboardLockSupportLinks {
    static func openRepository(_ config: CatKeyboardLockAppConfig) {
        KikiSettingsActions.openURL(config.repositoryURL)
    }
}
