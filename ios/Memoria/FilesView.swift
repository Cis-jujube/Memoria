import SwiftUI

struct FilesView: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeader("Files & Imports", subtitle: "Upload pipeline states before memories are changed")

                    importDropzone

                    if snapshot.files.isEmpty {
                        EmptyStateView(
                            symbolName: "doc.badge.plus",
                            title: "No imported files yet",
                            detail: "Photos, PDFs, and chat notes will show processing status here."
                        )
                    } else {
                        ForEach(snapshot.files) { file in
                            FileImportCard(file: file)
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle("Files")
            .memoriaInlineNavigationTitle()
        }
    }

    private var importDropzone: some View {
        DarkPremiumCard {
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(Color.memoriaInk)
                    .frame(width: 42, height: 42)
                    .background(Color.memoriaMist)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Import on web, review on iPhone")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Native upload hooks can attach to this surface after backend auth is shared.")
                        .font(.caption)
                        .foregroundStyle(Color.memoriaMist.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct FileImportCard: View {
    let file: ImportedFile

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: file.progress >= 1 ? "doc.text.magnifyingglass" : "doc.badge.clock")
                        .font(.headline)
                        .foregroundStyle(Color.memoriaInk)
                        .frame(width: 36, height: 36)
                        .background(Color.memoriaMist)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.filename)
                            .font(.headline)
                            .foregroundStyle(Color.memoriaInk)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(file.status)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(Int(file.progress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.memoriaInk)
                }

                ProgressView(value: file.progress)
                    .tint(Color.memoriaInk)
            }
        }
    }
}
