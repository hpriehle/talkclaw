import SwiftUI
import SharedModels

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var files: [FileItem] = []
    @State private var currentPath: String? = nil
    @State private var pathStack: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFile: FileItem?
    @State private var fileContent: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                Group {
                    if isLoading && files.isEmpty {
                        ProgressView("Loading files...")
                            .tint(Theme.Colors.accent)
                    } else if files.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "folder")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.Colors.textTertiary)
                            Text("This directory is empty")
                                .font(Theme.Typography.subhead)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    } else {
                        List(files) { file in
                            Button {
                                handleTap(file)
                            } label: {
                                FileRow(file: file)
                            }
                            .listRowBackground(Theme.Colors.surface1)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(currentPath.map { ($0 as NSString).lastPathComponent } ?? "Files")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if currentPath != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            navigateUp()
                        }
                        .foregroundStyle(Theme.Colors.accent)
                    }
                }
            }
            .refreshable {
                await loadFiles()
            }
            .task {
                await loadFiles()
            }
            .sheet(item: $selectedFile) { file in
                FilePreviewSheet(file: file, content: fileContent)
            }
        }
    }

    private func loadFiles() async {
        guard let client = appState.getAPIClient() else { return }
        isLoading = true
        errorMessage = nil
        do {
            files = try await client.listFiles(path: currentPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleTap(_ file: FileItem) {
        if file.isDirectory {
            pathStack.append(currentPath ?? "")
            currentPath = file.id
            Task { await loadFiles() }
        } else {
            selectedFile = file
            Task {
                guard let client = appState.getAPIClient() else { return }
                do {
                    let data = try await client.downloadFile(path: file.id)
                    fileContent = String(data: data, encoding: .utf8)
                } catch {
                    fileContent = "Failed to load: \(error.localizedDescription)"
                }
            }
        }
    }

    private func navigateUp() {
        currentPath = pathStack.popLast()
        if currentPath?.isEmpty == true { currentPath = nil }
        Task { await loadFiles() }
    }
}

struct FileRow: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: file.isDirectory ? "folder.fill" : iconForFile(file.name))
                .foregroundStyle(file.isDirectory ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if let size = file.size {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Spacer()

            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "go", "rs": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml": return "doc.text"
        case "md", "txt": return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }
}

struct FilePreviewSheet: View {
    let file: FileItem
    let content: String?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    if let content {
                        Text(content)
                            .font(Theme.Typography.mono)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ProgressView()
                            .tint(Theme.Colors.accent)
                            .padding()
                    }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Colors.accent)
                }
                if let content {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            UIPasteboard.general.string = content
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }
            }
        }
    }
}
