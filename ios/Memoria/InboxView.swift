import SwiftUI

struct InboxView: View {
    let snapshot: DashboardSnapshot
    let copy: NativeCopy
    let onConfirm: (PendingUpdate) -> Void
    let onDiscard: (PendingUpdate) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeader(copy.aiInboxTitle, subtitle: "Confirm before memories change")

                    if snapshot.pendingUpdates.isEmpty {
                        EmptyStateView(
                            symbolName: "tray",
                            title: "Inbox is clear",
                            detail: "New captures and imports will wait here for your review."
                        )
                    } else {
                        ForEach(snapshot.pendingUpdates) { update in
                            PendingUpdateCard(
                                update: update,
                                whySuggestedLabel: copy.whySuggested,
                                onConfirm: { onConfirm(update) },
                                onDiscard: { onDiscard(update) }
                            )
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle(copy.aiInboxTitle)
            .memoriaInlineNavigationTitle()
        }
    }
}

private struct PendingUpdateCard: View {
    let update: PendingUpdate
    let whySuggestedLabel: String
    let onConfirm: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(update.type)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.memoriaInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.memoriaMist)
                        .clipShape(Capsule())

                    Text(update.createdLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(update.personName)
                        .font(.headline)
                        .foregroundStyle(Color.memoriaInk)

                    Text(update.summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(whySuggestedLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(update.evidence)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.memoriaCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 10) {
                    Button(action: onDiscard) {
                        Label("Discard", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onConfirm) {
                        Label("Confirm", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.memoriaInk)
                }
                .controlSize(.large)
            }
        }
    }
}
