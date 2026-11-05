import Foundation
import RondoCore

/// Drives the Mole CLI (`mo`, https://github.com/tw93/mole). Rondo ships no cleaning logic of its own:
/// it reads Mole's previews, shows them, and runs the real command only after the user confirmed a preview.
@Observable
final class MoleService {
    enum Action: String, Sendable {
        case analyze, previewClean, clean, previewOptimize, optimize

        var arguments: [String] {
            switch self {
            case .analyze: ["analyze", "--json"]
            case .previewClean: ["clean", "--dry-run"]
            case .clean: ["clean"]
            case .previewOptimize: ["optimize", "--dry-run"]
            case .optimize: ["optimize"]
            }
        }

        var progressTitle: String {
            switch self {
            case .analyze: "Analyzing disk…"
            case .previewClean: "Looking for files to clean…"
            case .clean: "Cleaning…"
            case .previewOptimize: "Checking maintenance tasks…"
            case .optimize: "Optimizing…"
            }
        }
    }

    struct CleanPreview: Equatable {
        let report: MoleReport
        let list: MoleCleanList
    }

    /// Runs `mo` with arguments and returns its output; throws on a non-zero exit.
    typealias Runner = @Sendable (_ executable: String, _ arguments: [String]) async throws -> String

    static let installCommand = "brew install mole"
    static let homepage = URL(string: "https://github.com/tw93/mole")!

    private(set) var executable: String?
    private(set) var analysis: MoleAnalysis?
    private(set) var analyzedAt: Date?
    private(set) var cleanPreview: CleanPreview?
    private(set) var optimizePreview: MoleReport?
    /// Output of the last real `clean`/`optimize` run.
    private(set) var lastRun: (action: Action, report: MoleReport, date: Date)?
    private(set) var running: Action?
    private(set) var errorMessage: String?
    /// `mo analyze --json <path>` results by path, for the donut and the folder explorer.
    private(set) var folders: [String: MoleAnalysis] = [:]
    private(set) var loadingFolders: Set<String> = []
    private(set) var folderErrors: [String: String] = [:]

    /// Screenshots use a fixed home so no real user name appears.
    static let homePath = AppEnvironment.usesDemoData ? "/Users/demo" : FileManager.default.homeDirectoryForCurrentUser.path

    var isInstalled: Bool { executable != nil }
    var isBusy: Bool { running != nil }

    /// Set once Rondo has shown the "install Mole" onboarding, so it isn't shown on every launch.
    var hasOnboarded: Bool {
        get { access(keyPath: \.hasOnboarded); return defaults.bool(forKey: Self.onboardedKey) }
        set { withMutation(keyPath: \.hasOnboarded) { defaults.set(newValue, forKey: Self.onboardedKey) } }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let locate: () -> String?
    @ObservationIgnored private let runner: Runner
    @ObservationIgnored private let cleanListURL: URL
    private static let onboardedKey = "rondo.mole.hasOnboarded"
    /// Settings of the removed built-in Disk Clean (custom targets, unticked targets), dropped on launch.
    private static let obsoleteKeys = ["rondo.diskClean.customTargets", "rondo.diskClean.deselected"]

    init(defaults: UserDefaults,
         locate: @escaping () -> String? = { Shell.which("mo") },
         runner: @escaping Runner = MoleService.runProcess,
         cleanListURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/mole/clean-list.txt")) {
        self.defaults = defaults
        self.locate = locate
        self.runner = runner
        self.cleanListURL = cleanListURL
        Self.obsoleteKeys.forEach(defaults.removeObject(forKey:))
        executable = locate()
    }

    /// Re-checks whether `mo` is installed (after the user ran the install command).
    func refreshInstallation() {
        executable = locate()
    }

    // MARK: Actions

    func analyze() async {
        guard let output = await run(.analyze) else { return }
        do {
            publish(try MoleAnalysis.decode(output))
        } catch {
            errorMessage = "Mole returned an analysis Rondo couldn't read. Update Mole with `brew upgrade mole`."
        }
    }

    func previewClean() async {
        guard let output = await run(.previewClean) else { return }
        let list = (try? String(contentsOf: cleanListURL, encoding: .utf8)).map(MoleCleanList.parse) ?? MoleCleanList()
        cleanPreview = CleanPreview(report: MoleReport.parse(output), list: list)
    }

    /// Runs the real cleanup. Mole starts immediately without a terminal, so a preview must have been shown first.
    func clean() async {
        guard cleanPreview != nil else { return }
        guard let output = await run(.clean) else { return }
        finishRun(.clean, output)
        cleanPreview = nil // stale: the real run rescanned and removed files
        folders = [:]
        await analyze()
        await loadFolder(Self.homePath)
    }

    func previewOptimize() async {
        guard let output = await run(.previewOptimize) else { return }
        optimizePreview = MoleReport.parse(output)
    }

    func optimize() async {
        guard optimizePreview != nil else { return }
        guard let output = await run(.optimize) else { return }
        finishRun(.optimize, output)
        optimizePreview = nil
    }

    func publish(_ analysis: MoleAnalysis) {
        self.analysis = analysis
        analyzedAt = Date()
    }

    /// Analyzes one folder's direct children. Read-only, so it runs beside other commands; cached per path.
    func loadFolder(_ path: String, force: Bool = false) async {
        guard force || folders[path] == nil, !loadingFolders.contains(path) else { return }
        refreshInstallation()
        guard let executable else {
            folderErrors[path] = "Mole isn't installed. Install it with: \(Self.installCommand)"
            return
        }
        loadingFolders.insert(path)
        defer { loadingFolders.remove(path) }
        do {
            let output = try await runner(executable, ["analyze", "--json", path])
            folders[path] = try MoleAnalysis.decode(output)
            folderErrors[path] = nil
            if path == Self.homePath { analyzedAt = Date() }
        } catch {
            NSLog("Rondo: mo analyze \(path) failed: \(error)")
            folderErrors[path] = error is DecodingError
                ? "Mole returned an analysis Rondo couldn't read. Update Mole with `brew upgrade mole`."
                : MoleReport.stripANSI(error.localizedDescription)
        }
    }

    /// Screenshots only: a fixed preview instead of running `mo clean --dry-run`.
    func publishCleanPreview(_ preview: CleanPreview) {
        cleanPreview = preview
    }

    func publishFolder(_ analysis: MoleAnalysis, for path: String) {
        folders[path] = analysis
        analyzedAt = Date()
    }

    func dismissError() { errorMessage = nil }

    // MARK: Running

    private func finishRun(_ action: Action, _ output: String) {
        lastRun = (action, MoleReport.parse(output), Date())
    }

    /// One command at a time; returns nil (with `errorMessage` set) when Mole is missing or fails.
    private func run(_ action: Action) async -> String? {
        guard running == nil else { return nil }
        refreshInstallation()
        guard let executable else {
            errorMessage = "Mole isn't installed. Install it with: \(Self.installCommand)"
            return nil
        }
        running = action
        errorMessage = nil
        defer { running = nil }
        do {
            return try await runner(executable, action.arguments)
        } catch {
            NSLog("Rondo: mo \(action.arguments.joined(separator: " ")) failed: \(error)")
            errorMessage = MoleReport.stripANSI(error.localizedDescription)
            return nil
        }
    }

    /// Runs `mo` off the main thread with stdin closed (non-interactive mode) and Homebrew on PATH,
    /// since an app launched from Finder gets a minimal PATH that Mole's helpers aren't on.
    nonisolated static let runProcess: Runner = { executable, arguments in
        var environment = Foundation.ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        environment["NO_COLOR"] = "1"
        return try await Task.detached(priority: .userInitiated) {
            try Shell.run(executable, arguments, environment: environment)
        }.value
    }
}
