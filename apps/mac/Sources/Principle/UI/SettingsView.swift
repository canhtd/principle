import AppKit
import PrincipleCore
import SwiftUI

/// The four things the app cannot guess: which model answers, where the repo is,
/// which `claude` binary to spawn, and whether that binary can run at all.
///
/// Every field writes straight through to the shared defaults suite (KTD5), so
/// there is no Save button and nothing to lose by closing the window.
struct SettingsView: View {
    @State private var settings = AppSettings()
    @State private var availability: EngineAvailability?
    @State private var isChecking = false

    var body: some View {
        Form {
            Section("Model trả lời") {
                Picker("Model", selection: $settings.responseModel) {
                    ForEach(AppSettings.selectableModels, id: \.self) { alias in
                        Text(ModelAlias.displayName(alias)).tag(alias)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                caption("Áp dụng cho phiên mới. Phiên đã tạo giữ nguyên model của nó — đổi model thì tạo phiên mới.")
            }

            Section("Thư mục repo") {
                pathField(
                    text: $settings.repoPath,
                    prompt: RepoLocation.current(defaults: nil).path,
                    choose: chooseRepo
                )
                caption("Đang dùng: \(settings.repoURL.path)")
                warning(settings.repoPathWarning)
            }

            Section("Claude Code") {
                pathField(
                    text: $settings.claudeBinaryOverride,
                    prompt: "Để trống để app tự tìm",
                    choose: chooseBinary
                )
                caption("Đang dùng: \(settings.resolvedBinary()?.path ?? "chưa tìm thấy")")
                warning(settings.binaryOverrideWarning)
                caption("Đổi thư mục repo hoặc đường dẫn Claude Code sẽ có hiệu lực sau khi mở lại app.")
            }

            Section("Trạng thái engine") {
                engineStatus
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 620)
        .task { await check() }
    }

    // MARK: - Engine status

    @ViewBuilder
    private var engineStatus: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusTint)
            Text(statusTitle)
                .font(Typography.body)
            Spacer()
            Button(isChecking ? "Đang kiểm tra…" : "Kiểm tra lại") {
                Task { await check() }
            }
            .disabled(isChecking)
        }
        if let guidance = statusGuidance {
            Text(guidance)
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTitle: String { availability?.settingsTitle ?? "Đang kiểm tra…" }

    private var statusGuidance: String? { availability?.guidance }

    private var statusIcon: String {
        switch availability {
        case .ready: "checkmark.circle.fill"
        case .notInstalled, .loggedOut, .skillMissing: "exclamationmark.triangle.fill"
        case nil: "clock"
        }
    }

    private var statusTint: Color {
        switch availability {
        case .ready: .green
        case .notInstalled, .loggedOut, .skillMissing: .orange
        case nil: .secondary
        }
    }

    /// Runs the same probe the chat uses (KTD4), through whatever override is in
    /// the field right now — so a path can be checked before it is trusted.
    private func check() async {
        isChecking = true
        availability = await settings.availabilityProbe().currentAvailability()
        isChecking = false
    }

    // MARK: - Pieces

    @ViewBuilder
    private func pathField(text: Binding<String>, prompt: String, choose: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            TextField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .font(Typography.body)
                // A Form otherwise reserves a label column for the empty label,
                // which makes the two path rows come out different widths.
                .labelsHidden()
                .frame(maxWidth: .infinity)
            Button("Chọn…", action: choose)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .lineSpacing(Typography.captionLineSpacing)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func warning(_ text: String?) -> some View {
        if let text {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Pickers

    private func chooseRepo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Chọn"
        panel.directoryURL = settings.repoURL
        if panel.runModal() == .OK, let url = panel.url { settings.repoPath = url.path }
    }

    private func chooseBinary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        // The binary usually lives in a dot-directory the panel hides by default.
        panel.showsHiddenFiles = true
        panel.prompt = "Chọn"
        if panel.runModal() == .OK, let url = panel.url { settings.claudeBinaryOverride = url.path }
    }
}

#Preview {
    SettingsView()
}
