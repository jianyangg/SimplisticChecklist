import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "checklist")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Simplistic Checklist")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)

                        Text("A fast, calm checklist that stays out of the way.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inspired by the idea that a short checklist can keep important work on track.")
                        Text("Your lists stay on this device. There are no accounts, ads, analytics, or network requests.")
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        Text("“No wise pilot, no matter how great his talent and experience, fails to use his checklist.”")
                            .italic()
                            .multilineTextAlignment(.center)
                        Text("— Charlie Munger")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 520)

                    if let appVersion {
                        Text("Version \(appVersion)")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
