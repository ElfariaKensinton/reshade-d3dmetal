import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct ReShadeMetalInstallerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1040, height: 790)
    }
}

private enum InstallerPage: String, CaseIterable {
    case install = "Install"
    case shaders = "Shaders"
    case guide = "Guide"

    var symbol: String {
        switch self {
        case .install: "square.and.arrow.down"
        case .shaders: "slider.horizontal.3"
        case .guide: "book.closed"
        }
    }

    var title: String {
        switch self {
        case .install: "Game installation"
        case .shaders: "Per-game shaders"
        case .guide: "Setup guide"
        }
    }

    var subtitle: String {
        switch self {
        case .install: "Install the verified ReShade runtime into a Windows game folder."
        case .shaders: "Manage a separate shader list and enabled state for every game."
        case .guide: "Follow these steps to use ReShade with a Mac game wrapper."
        }
    }
}

private struct RegisteredGame: Identifiable {
    let executablePath: String
    var isInstalled: Bool
    var techniques: [ShaderTechnique]
    var isExpanded: Bool
    var readError: String?
    var searchText: String

    var id: String { executablePath }
    var executableURL: URL { URL(fileURLWithPath: executablePath) }
    var directoryURL: URL { executableURL.deletingLastPathComponent() }
    var name: String { executableURL.deletingPathExtension().lastPathComponent }
}

private struct GameCardActionButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 34, alignment: .center)
            .foregroundStyle(isDestructive ? Color.red : Color.primary.opacity(0.85))
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.72 : 1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(configuration.isPressed ? 0.23 : 0.13), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.94 : 1)
    }
}

@MainActor
private final class InstallerViewModel: ObservableObject {
    @Published var page: InstallerPage = .install
    @Published var selectedGame: URL?
    @Published var installShaders = true
    @Published var reshadeVersion = InstallerService.defaultVersion
    @Published var games: [RegisteredGame] = []
    @Published var isWorking = false
    @Published var isInstalled = false
    @Published var status = "Choose a 64-bit Windows game executable to begin."
    @Published var logEntries: [String] = []
    @Published var showAlert = false
    @Published var alertMessage = ""

    var gameDirectory: URL? { selectedGame?.deletingLastPathComponent() }
    var gameName: String { selectedGame?.deletingPathExtension().lastPathComponent ?? "No game selected" }
    var gamePath: String { gameDirectory?.path ?? "Choose the actual game .exe inside your Wine, Whisky, or CrossOver bottle." }
    var selectedBuild: ReShadeBuild? {
        InstallerService.supportedBuilds.first(where: { $0.version == reshadeVersion })
    }

    private static var registryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReShadeMetalInstaller", isDirectory: true)
            .appendingPathComponent("games.json")
    }

    init() {
        let storedPaths = (try? Data(contentsOf: Self.registryURL))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        var seen = Set<String>()
        let existingPaths = storedPaths.filter { path in
            guard seen.insert(path).inserted else { return false }
            return FileManager.default.fileExists(atPath: path)
        }
        games = existingPaths.map { Self.makeGameEntry($0, expanded: false) }
        if existingPaths != storedPaths { persistGamePaths() }
    }

    func chooseGame() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.title = "Select a Windows game executable"
        panel.message = "Choose the game's 64-bit .exe. ReShade will be installed beside this file."
        panel.prompt = "Choose Game"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .item]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try InstallerService.validateGameExecutable(url)
            selectedGame = url
            isInstalled = InstallerService.hasInstallation(in: url.deletingLastPathComponent())
            status = isInstalled ? "A ReShade installation was detected for this game." : "Ready to install beside \(url.lastPathComponent)."
            logEntries = []
            registerGame(url)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func addGame() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.title = "Add a game with ReShade installed"
        panel.message = "Choose the game's 64-bit .exe. Only games with a detected ReShade installation appear on the Shaders page."
        panel.prompt = "Add Game"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .item]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try InstallerService.validateGameExecutable(url)
            guard InstallerService.hasInstallation(in: url.deletingLastPathComponent()) else {
                showError("ReShade is not installed beside this game's executable. Install ReShade first; only installed games appear on the Shaders page.")
                return
            }
            registerGame(url, expand: true)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func refreshGames() {
        guard !isWorking else { return }
        games = games.map { game in
            Self.makeGameEntry(game.executablePath, expanded: game.isExpanded, searchText: game.searchText)
        }
    }

    func removeGame(_ id: String) {
        guard !isWorking else { return }
        games.removeAll { $0.id == id }
        persistGamePaths()
    }

    func registerGame(_ url: URL, expand: Bool = false) {
        let path = url.standardizedFileURL.path
        if let index = games.firstIndex(where: { $0.id == path }) {
            let expanded = expand || games[index].isExpanded
            let searchText = games[index].searchText
            games[index] = Self.makeGameEntry(path, expanded: expanded, searchText: searchText)
        } else {
            games.append(Self.makeGameEntry(path, expanded: expand))
            persistGamePaths()
        }
    }

    func refreshRegisteredGame(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard let index = games.firstIndex(where: { $0.id == path }) else {
            registerGame(url)
            return
        }
        games[index] = Self.makeGameEntry(path, expanded: games[index].isExpanded, searchText: games[index].searchText)
    }

    func setGameExpanded(_ id: String, expanded: Bool) {
        guard let index = games.firstIndex(where: { $0.id == id }) else { return }
        games[index].isExpanded = expanded
    }

    func isGameInstalled(_ id: String) -> Bool {
        games.first(where: { $0.id == id })?.isInstalled ?? false
    }

    func techniques(for id: String) -> [ShaderTechnique] {
        games.first(where: { $0.id == id })?.techniques ?? []
    }

    func searchText(for id: String) -> String {
        games.first(where: { $0.id == id })?.searchText ?? ""
    }

    func setSearchText(_ text: String, for id: String) {
        guard let index = games.firstIndex(where: { $0.id == id }) else { return }
        games[index].searchText = text
    }

    func filteredTechniques(for id: String) -> [ShaderTechnique] {
        let values = techniques(for: id)
        let query = searchText(for: id).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return values }
        return values.filter { "\($0.name) \($0.shaderFile)".localizedCaseInsensitiveContains(query) }
    }

    func enabledTechniqueCount(for id: String) -> Int {
        techniques(for: id).filter(\.isEnabled).count
    }

    func techniqueEnabled(_ techniqueID: String, for gameID: String) -> Bool {
        techniques(for: gameID).first(where: { $0.id == techniqueID })?.isEnabled ?? false
    }

    func setTechniqueEnabled(_ id: String, enabled: Bool, gamePath: String) {
        guard !isWorking, let gameIndex = games.firstIndex(where: { $0.id == gamePath }),
              games[gameIndex].isInstalled,
              let techniqueIndex = games[gameIndex].techniques.firstIndex(where: { $0.id == id }) else { return }
        let previousValue = games[gameIndex].techniques[techniqueIndex].isEnabled
        guard previousValue != enabled else { return }
        games[gameIndex].techniques[techniqueIndex].isEnabled = enabled
        do {
            try InstallerService.saveTechniqueStates(games[gameIndex].techniques, in: games[gameIndex].directoryURL)
            status = "\(games[gameIndex].techniques[techniqueIndex].name) \(enabled ? "enabled" : "disabled") for \(games[gameIndex].name)."
        } catch {
            games[gameIndex].techniques[techniqueIndex].isEnabled = previousValue
            showError(error.localizedDescription)
        }
    }

    func setAllTechniques(enabled: Bool, gamePath: String) {
        guard !isWorking, let gameIndex = games.firstIndex(where: { $0.id == gamePath }),
              games[gameIndex].isInstalled, !games[gameIndex].techniques.isEmpty else { return }
        let previous = games[gameIndex].techniques
        games[gameIndex].techniques = previous.map { technique in
            var updated = technique
            updated.isEnabled = enabled
            return updated
        }
        do {
            try InstallerService.saveTechniqueStates(games[gameIndex].techniques, in: games[gameIndex].directoryURL)
            status = "\(enabled ? "Enabled" : "Disabled") all listed shaders for \(games[gameIndex].name)."
        } catch {
            games[gameIndex].techniques = previous
            showError(error.localizedDescription)
        }
    }

    func addEffects(to gamePath: String) {
        guard !isWorking, let gameIndex = games.firstIndex(where: { $0.id == gamePath }),
              games[gameIndex].isInstalled else { return }

        let gameName = games[gameIndex].name
        let gameDirectory = games[gameIndex].directoryURL
        let panel = NSOpenPanel()
        panel.title = "Add effects to \(gameName)"
        panel.message = "Choose .fx effect files, .fxh include files, or a folder of effects. Files are imported into this game's shader folder only."
        panel.prompt = "Add Effects"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fx") ?? .item,
            UTType(filenameExtension: "fxh") ?? .item,
            .folder
        ]
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let selectedURLs = panel.urls
        isWorking = true
        status = "Adding effects to \(gameName)…"
        Task {
            do {
                let importedCount = try await Task.detached(priority: .userInitiated) {
                    try InstallerService.importShaderEffects(from: selectedURLs, into: gameDirectory)
                }.value
                refreshRegisteredGame(URL(fileURLWithPath: gamePath))
                status = "Imported \(importedCount) effect/include file\(importedCount == 1 ? "" : "s") for \(gameName)."
                record(status)
            } catch {
                record("Could not add effects for \(gameName): \(error.localizedDescription)")
                showError(error.localizedDescription)
            }
            isWorking = false
        }
    }

    func importPreset(for gamePath: String) {
        guard !isWorking, let gameIndex = games.firstIndex(where: { $0.id == gamePath }),
              games[gameIndex].isInstalled else { return }

        let gameName = games[gameIndex].name
        let gameDirectory = games[gameIndex].directoryURL
        let panel = NSOpenPanel()
        panel.title = "Import a ReShade preset for \(gameName)"
        panel.message = "Choose the preset .ini downloaded from Nexus Mods. The current preset will be backed up before it is replaced."
        panel.prompt = "Import Preset"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "ini") ?? .item]
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        isWorking = true
        status = "Importing preset for \(gameName)…"
        Task {
            do {
                let message = try await Task.detached(priority: .userInitiated) {
                    try InstallerService.importPreset(from: selectedURL, into: gameDirectory)
                }.value
                refreshRegisteredGame(URL(fileURLWithPath: gamePath))
                status = message
                record(message)
            } catch {
                record("Could not import a preset for \(gameName): \(error.localizedDescription)")
                showError(error.localizedDescription)
            }
            isWorking = false
        }
    }

    func install() {
        guard let selectedGame, !isWorking else { return }
        guard let build = selectedBuild else {
            showError("That ReShade version has no verified D3DMetal patch profile. Choose a compatible version from the list.")
            return
        }
        guard !isInstalled else {
            showError("This game already has a ReShade Metal installation. Uninstall it first to restore the saved files before installing again.")
            return
        }
        isWorking = true
        logEntries = []
        status = "Preparing ReShade \(build.version) installation…"
        let shaderOption = installShaders
        let version = build.version
        let progress: @Sendable (String) -> Void = { [weak self] message in
            Task { @MainActor in self?.record(message) }
        }

        Task {
            do {
                let summary = try await InstallerService.install(gameExecutable: selectedGame, installShaders: shaderOption, reshadeVersion: version, progress: progress)
                record(summary)
                status = summary
                isInstalled = true
                registerGame(selectedGame)
                refreshRegisteredGame(selectedGame)
            } catch {
                record("Failed: \(error.localizedDescription)")
                status = "Installation failed. Your game files were left untouched or restored."
                showError(error.localizedDescription)
                isInstalled = InstallerService.hasInstallation(in: selectedGame.deletingLastPathComponent())
                refreshRegisteredGame(selectedGame)
            }
            isWorking = false
        }
    }

    func uninstall() {
        guard let selectedGame else { return }
        restore(gameExecutable: selectedGame)
    }

    func restoreGame(_ id: String) {
        guard let game = games.first(where: { $0.id == id }), game.isInstalled else { return }
        restore(gameExecutable: game.executableURL)
    }

    private func restore(gameExecutable: URL) {
        guard !isWorking else { return }
        isWorking = true
        logEntries = []
        let targetPath = gameExecutable.standardizedFileURL.path
        let targetName = gameExecutable.deletingPathExtension().lastPathComponent
        status = "Restoring ReShade for \(targetName)…"
        let progress: @Sendable (String) -> Void = { [weak self] message in
            Task { @MainActor in self?.record(message) }
        }

        Task {
            do {
                let summary = try InstallerService.uninstall(gameExecutable: gameExecutable, progress: progress)
                record(summary)
                status = summary
                if selectedGame?.standardizedFileURL.path == targetPath { isInstalled = false }
                refreshRegisteredGame(gameExecutable)
            } catch {
                record("Failed: \(error.localizedDescription)")
                status = "Could not restore ReShade for \(targetName). Existing files were preserved."
                showError(error.localizedDescription)
                if selectedGame?.standardizedFileURL.path == targetPath {
                    isInstalled = InstallerService.hasInstallation(in: gameExecutable.deletingLastPathComponent())
                }
                refreshRegisteredGame(gameExecutable)
            }
            isWorking = false
        }
    }

    private static func makeGameEntry(_ path: String, expanded: Bool, searchText: String = "") -> RegisteredGame {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let installed = InstallerService.hasInstallation(in: url.deletingLastPathComponent())
        var techniques: [ShaderTechnique] = []
        var readError: String?
        if installed {
            do {
                techniques = try InstallerService.loadTechniques(in: url.deletingLastPathComponent())
            } catch {
                readError = error.localizedDescription
            }
        }
        return RegisteredGame(executablePath: url.path, isInstalled: installed, techniques: techniques,
                              isExpanded: expanded, readError: readError, searchText: searchText)
    }

    private func persistGamePaths() {
        do {
            let registryURL = Self.registryURL
            try FileManager.default.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let paths = games.map(\.executablePath)
            try JSONEncoder().encode(paths).write(to: registryURL, options: .atomic)
        } catch {
            showError("Could not save the game list: \(error.localizedDescription)")
        }
    }

    private func record(_ message: String) {
        status = message
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logEntries.append("\(formatter.string(from: Date()))  \(message)")
        if logEntries.count > 80 { logEntries.removeFirst(logEntries.count - 80) }
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
private struct ContentView: View {
    @StateObject private var model = InstallerViewModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1)
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    Group {
                        switch model.page {
                        case .install: installPage
                        case .shaders: shadersPage
                        case .guide: guidePage
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(minWidth: 920, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.page) { _, newPage in
            if newPage == .shaders { model.refreshGames() }
        }
        .alert("ReShade Metal Installer", isPresented: $model.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.alertMessage)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.78, blue: 0.72), Color(red: 0.18, green: 0.46, blue: 0.84)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "sparkles.tv")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ReShade Metal").font(.system(size: 15, weight: .bold))
                    Text("MAC GAME TOOLS").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.3).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 34)

            Text("WORKSPACE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            ForEach(InstallerPage.allCases, id: \.self) { item in
                Button {
                    model.page = item
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 20)
                        Text(item.rawValue)
                        Spacer()
                        if model.page == item {
                            RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3, height: 20)
                        }
                    }
                    .font(.system(size: 13, weight: model.page == item ? .semibold : .medium))
                    .foregroundStyle(model.page == item ? Color.primary : Color.secondary)
                    .padding(.leading, 14)
                    .padding(.trailing, 12)
                    .frame(height: 42)
                    .background(model.page == item ? Color.accentColor.opacity(0.11) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("macOS 26 or later").font(.system(size: 11, weight: .medium))
                }
                Text("D3DMetal compatibility build")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("\(InstallerService.supportedBuilds.count) verified ReShade builds • x64")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.page.title)
                    .font(.system(size: 20, weight: .bold))
                Text(model.page.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(Color.green)
                Text("SHA-256 verified")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.09), in: Capsule())
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 22)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
    }

    private var installPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A better look for your games.")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                    Text("Choose a game executable. ReShade Metal downloads the official runtime, verifies it, applies the D3DMetal compatibility patch, and installs it beside your game.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 70, height: 70)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.bottom, 2)

            sectionHeader(number: "01", title: "Select your game", subtitle: "Pick the actual 64-bit .exe inside your Wine, Whisky, or CrossOver bottle.")
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 13) {
                    Image(systemName: model.selectedGame == nil ? "folder.badge.questionmark" : "gamecontroller")
                        .font(.system(size: 20))
                        .foregroundStyle(model.selectedGame == nil ? Color.secondary : Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.gameName).font(.system(size: 14, weight: .semibold))
                        Text(model.gamePath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 4)
                    Button(model.selectedGame == nil ? "Choose game…" : "Change") { model.chooseGame() }
                        .buttonStyle(.bordered)
                        .disabled(model.isWorking)
                }
            if model.isInstalled {
                    Label("A ReShade installation was detected for this game.", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green)
                } else if model.selectedGame != nil {
                    Label("64-bit Windows executable detected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green)
                }
            }
            .padding(17)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.primary.opacity(0.07), lineWidth: 1))

            sectionHeader(number: "02", title: "Choose the ReShade version", subtitle: "Only versions with a verified D3DMetal patch profile can be installed.")
            VStack(alignment: .leading, spacing: 12) {
                Picker("ReShade version to download", selection: $model.reshadeVersion) {
                    ForEach(InstallerService.supportedBuilds) { build in
                        Text("ReShade \(build.version) · Verified x64").tag(build.version)
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.isWorking)

                if let build = model.selectedBuild {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill").font(.system(size: 20)).foregroundStyle(Color.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ReShade \(build.version) · D3DMetal · DXGI · 64-bit")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Official setup and runtime hashes are checked before patching; the patched DLL hash is verified before installation.")
                                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Label("This version has no verified patch profile and cannot be installed.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.orange)
                }
                Text("More versions will appear here only after their patch locations and output hashes have been verified. Currently compatible: \(InstallerService.supportedBuilds.map(\.version).joined(separator: ", ")).")
                    .font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.25), lineWidth: 1))

            sectionHeader(number: "03", title: "Effects and install", subtitle: "Existing files are preserved in a backup folder before anything is replaced.")
            Toggle(isOn: $model.installShaders) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install the official shader effects").font(.system(size: 13, weight: .semibold))
                    Text("Downloads the ReShade shader repository into reshade-shaders/ beside the game.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 2)
            .disabled(model.isWorking)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        if model.isWorking { ProgressView().controlSize(.small) }
                        else { Image(systemName: model.isInstalled ? "checkmark.shield.fill" : "info.circle.fill").foregroundStyle(model.isInstalled ? Color.green : Color.accentColor) }
                        Text(model.status).font(.system(size: 11, weight: .medium)).lineLimit(2)
                    }
                    Text("Installer downloads directly from reshade.me and checks the published build hash.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                if model.isInstalled {
                    Button(role: .destructive) { model.uninstall() } label: {
                        Label("Restore backup", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isWorking)
                } else {
                    Button { model.install() } label: {
                        Label(model.isWorking ? "Working…" : "Install ReShade", systemImage: "arrow.down.to.line")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(minWidth: 132)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedGame == nil || model.isWorking)
                }
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))

            if !model.logEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ACTIVITY").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") { model.logEntries = [] }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.logEntries.suffix(8).enumerated()), id: \.offset) { _, entry in
                        Text(entry).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange)
                Text("The D3DMetal patch is experimental and version-specific. Choose one of the verified x64 builds above. Use it only with games you are allowed to modify; injection may conflict with anti-cheat systems.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }

    private var guidePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("From install to in-game overlay")
                    .font(.system(size: 27, weight: .bold, design: .rounded)).tracking(-0.5)
                Text("A native macOS front end for the ReShade runtime used by Windows games running in a Wine-based wrapper.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                guideStep(number: "1", title: "Prepare your game wrapper", body: "Install and launch the game once in CrossOver, Whisky, or Wine. Close the game before patching. Select D3DMetal as the graphics backend where your wrapper supports it.")
                guideDivider
                guideStep(number: "2", title: "Choose the real game executable", body: "In Install, choose the game's 64-bit .exe inside its Windows bottle or prefix. Avoid a launcher if you know the actual game executable.")
                guideDivider
                guideStep(number: "3", title: "Install the verified runtime", body: "The app downloads the selected verified ReShade setup from reshade.me, verifies its SHA-256, extracts ReShade64.dll, checks the DLL hash, and applies the matching version-specific DXGI patch. It then writes dxgi.dll and ReShade configuration files beside the game.")
                guideDivider
                guideStep(number: "4", title: "Set the DXGI library override", body: "In your wrapper's Wine configuration, set the dxgi library override to Native (with Builtin fallback if that option is available). Leave D3DMetal enabled. Exact control names vary by wrapper and version.")
                guideDivider
                guideStep(number: "5", title: "Launch and open ReShade", body: "Start the game through the same wrapper. On first launch the effects compile; give it a moment. Press Home to open the ReShade overlay, then select or create a preset.")
                guideDivider
                guideStep(number: "6", title: "Restore or uninstall", body: "Return to this app, select the same game .exe, and choose Restore backup. The app removes its installed files and restores the files saved before installation. The backup folder is retained for recovery.")
            }
            .padding(.horizontal, 18)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Label("What this build supports", systemImage: "checkmark.seal.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.green)
                Text("64-bit Windows games using the DXGI path with a version listed in the installer as verified. Verified ReShade versions: \(InstallerService.supportedBuilds.map(\.version).joined(separator: ", ")). The installer refuses unexpected setup/runtime hashes and does not patch unsupported versions.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Link("Official ReShade website", destination: URL(string: "https://reshade.me/")!)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(17)
            .background(Color.green.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private var shadersPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shaders by game")
                    .font(.system(size: 27, weight: .bold, design: .rounded)).tracking(-0.5)
                Text("Every game has its own shader list, search filter, and saved enabled states. Changes are written to that game's ReShadePreset.ini.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let installedGames = model.games.filter(\.isInstalled)
                    Text("Games with ReShade installed").font(.system(size: 15, weight: .bold))
                    Text("\(installedGames.count) game\(installedGames.count == 1 ? "" : "s") available")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.addGame() } label: {
                    Label("Add game", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
            }

            let installedGames = model.games.filter(\.isInstalled)
            if installedGames.isEmpty {
                ContentUnavailableView("No games with ReShade installed", systemImage: "gamecontroller", description: Text("Only games with a detected ReShade installation appear here. Install ReShade from the Install page, or add a game that already has ReShade installed."))
                    .frame(maxWidth: .infinity).padding(.vertical, 26)
            } else {
                VStack(spacing: 12) {
                    ForEach(installedGames) { game in
                        gameShaderCard(game)
                    }
                }
            }
        }
    }

    private func gameShaderCard(_ game: RegisteredGame) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 18)).foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 45)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name).font(.system(size: 14, weight: .semibold))
                    Text(game.executablePath)
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(2).textSelection(.enabled)
                    HStack(spacing: 6) {
                        Circle().fill(game.isInstalled ? Color.green : Color.secondary).frame(width: 6, height: 6)
                        if game.isInstalled {
                            Text("\(game.techniques.count) effects · \(model.enabledTechniqueCount(for: game.id)) enabled")
                        } else {
                            Text("ReShade not installed")
                        }
                    }
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(game.isInstalled ? Color.green : Color.secondary)
                }
                Spacer(minLength: 4)
                HStack(alignment: .center, spacing: 7) {
                    Button(role: .destructive) {
                        model.restoreGame(game.id)
                    } label: {
                        Label("Restore backup", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(GameCardActionButtonStyle(isDestructive: true))
                    .frame(width: 126, height: 45, alignment: .center)
                    .disabled(model.isWorking)
                    .help("Restore the backup for \(game.name) and remove its ReShade installation.")
                    .accessibilityLabel("Restore backup for \(game.name)")

                    Menu {
                        Button(role: .destructive) {
                            model.removeGame(game.id)
                        } label: {
                            Label("Remove from list", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(GameCardActionButtonStyle())
                    .frame(width: 34, height: 45, alignment: .center)
                    .help("Remove this game from the management list. Game files will not be changed.")
                    .disabled(model.isWorking)

                    Button {
                        model.setGameExpanded(game.id, expanded: !game.isExpanded)
                    } label: {
                        Image(systemName: game.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(GameCardActionButtonStyle())
                    .frame(width: 34, height: 34, alignment: .center)
                    .accessibilityLabel(game.isExpanded ? "Collapse \(game.name)" : "Expand \(game.name)")
                }
            }
            .padding(15)

            if game.isExpanded {
                Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
                if game.isInstalled {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Effects and preset").font(.system(size: 12, weight: .semibold))
                            Text("Import shader files or activate a downloaded ReShade .ini preset for this game.")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            model.importPreset(for: game.id)
                        } label: {
                            Label("Import preset", systemImage: "doc.badge.arrow.up")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isWorking)
                        Button {
                            model.addEffects(to: game.id)
                        } label: {
                            Label("Add effects", systemImage: "plus")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                    }
                    .padding(13)
                    Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
                }
                if !game.isInstalled {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Install ReShade for this game first", systemImage: "info.circle.fill")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        Text("Open Install, choose this executable, then install the verified ReShade build with the shader collection enabled. This game's shader settings will load here afterward.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(15)
                } else if let readError = game.readError {
                    ContentUnavailableView("Could not read shaders", systemImage: "exclamationmark.triangle", description: Text(readError))
                        .padding(.vertical, 10)
                } else if game.techniques.isEmpty {
                    ContentUnavailableView("No shader effects found", systemImage: "square.stack.3d.up.slash", description: Text("No readable .fx techniques were found in this game's shader folder. Use Add effects above to import .fx files or a folder of effects."))
                        .padding(.vertical, 10)
                } else {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                            Text("\(model.enabledTechniqueCount(for: game.id)) of \(game.techniques.count) enabled")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer(minLength: 6)
                            Button("Enable all") { model.setAllTechniques(enabled: true, gamePath: game.id) }
                                .buttonStyle(.bordered)
                                .disabled(model.isWorking || model.enabledTechniqueCount(for: game.id) == game.techniques.count)
                            Button("Disable all") { model.setAllTechniques(enabled: false, gamePath: game.id) }
                                .buttonStyle(.bordered)
                                .disabled(model.isWorking || model.enabledTechniqueCount(for: game.id) == 0)
                        }

                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search this game's shaders…", text: Binding(
                                get: { model.searchText(for: game.id) },
                                set: { model.setSearchText($0, for: game.id) }
                            ))
                            .textFieldStyle(.plain)
                            if !model.searchText(for: game.id).isEmpty {
                                Button { model.setSearchText("", for: game.id) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))

                        VStack(spacing: 0) {
                            let filtered = model.filteredTechniques(for: game.id)
                            if filtered.isEmpty {
                                Text("No shaders match this game's search.")
                                    .font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(20)
                            } else {
                                ForEach(filtered) { technique in
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(technique.name).font(.system(size: 12, weight: .semibold))
                                            Text(technique.shaderFile).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 5)
                                        Text(model.techniqueEnabled(technique.id, for: game.id) ? "Enabled" : "Disabled")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(model.techniqueEnabled(technique.id, for: game.id) ? Color.green : Color.secondary)
                                        Toggle("Enable \(technique.name)", isOn: Binding(
                                            get: { model.techniqueEnabled(technique.id, for: game.id) },
                                            set: { model.setTechniqueEnabled(technique.id, enabled: $0, gamePath: game.id) }
                                        ))
                                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                                        .disabled(model.isWorking)
                                        .accessibilityLabel("Enable \(technique.name) from \(technique.shaderFile) for \(game.name)")
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    if technique.id != filtered.last?.id {
                                        Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.leading, 10)
                                    }
                                }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.07), lineWidth: 1))
                    }
                    .padding(13)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
    private var guideDivider: some View {
        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1).padding(.leading, 45)
    }

    private func sectionHeader(number: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guideStep(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 17)
    }
}
