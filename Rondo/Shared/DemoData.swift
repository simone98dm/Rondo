import Foundation

/// Deterministic sample data for screenshots (`--demo-data`), so docs never show the real machine.
enum DemoData {
    static let processes: [ProcessInfo] = [
        process(101, "Safari", "/Applications/Safari.app/Contents/MacOS/Safari", cpu: 12.4, ram: 1_800),
        process(102, "Safari Web Content", "/Applications/Safari.app/Contents/XPCServices/WebContent", parent: 101, cpu: 6.1, ram: 950),
        process(103, "Xcode", "/Applications/Xcode.app/Contents/MacOS/Xcode", cpu: 18.2, ram: 2_400),
        process(104, "Music", "/System/Applications/Music.app/Contents/MacOS/Music", cpu: 2.3, ram: 420),
        process(105, "Mail", "/System/Applications/Mail.app/Contents/MacOS/Mail", cpu: 0.8, ram: 380),
        process(106, "Notes", "/System/Applications/Notes.app/Contents/MacOS/Notes", cpu: 0.4, ram: 260),
        process(107, "Finder", "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder", cpu: 0.6, ram: 210),
        process(108, "WindowServer", "/System/Library/PrivateFrameworks/SkyLight.framework/WindowServer", system: true, cpu: 9.5, ram: 640),
        process(109, "kernel_task", "", system: true, cpu: 4.2, ram: 900),
    ]

    private static func process(_ pid: Int32, _ name: String, _ path: String, parent: Int32 = 1, system: Bool = false,
                                cpu: Double, ram: UInt64) -> ProcessInfo {
        ProcessInfo(pid: pid, parentPID: parent, name: name, path: path, isSystem: system, cpuPercent: cpu, ramBytes: ram << 20)
    }

    /// Snapshot `step` of a gentle, repeating load curve.
    static func snapshot(step: Int) -> SystemSnapshot {
        let wave = (sin(Double(step) / 6) + 1) / 2
        var snap = SystemSnapshot()
        snap.cpuPercent = 18 + 22 * wave
        snap.ramTotal = 16 << 30
        snap.ramUsed = UInt64(Double(9 << 30) + Double(2 << 30) * wave)
        snap.ramWired = 2 << 30
        snap.ramCompressed = 1 << 30
        snap.diskTotal = 494 << 30
        snap.diskUsed = 312 << 30
        snap.netIn = 180_000 + 900_000 * wave * wave
        snap.netOut = 40_000 + 120_000 * (1 - wave)
        snap.processes = processes
        snap.sensors = SensorReadings(gpuPercent: 14 + 10 * wave, cpuTemperature: 46 + 6 * wave,
                                      gpuTemperature: 41 + 4 * wave, fanRPMs: [])
        return snap
    }

    static let analysis = MoleAnalysis(path: "/", scanStatus: .complete, entries: [
        .init(name: "User Library", path: "/Users/demo/Library", size: 61 << 30),
        .init(name: "Home", path: "/Users/demo", size: 48 << 30),
        .init(name: "Applications", path: "/Applications", size: 32 << 30),
        .init(name: "Xcode Simulators", path: "/Users/demo/Library/Developer/CoreSimulator/Devices", size: 21 << 30, insight: true),
        .init(name: "Gradle Cache", path: "/Users/demo/.gradle/caches", size: 9 << 30, insight: true, cleanable: true),
        .init(name: "Old Downloads (90d+)", path: "/Users/demo/Downloads", size: 6 << 30, insight: true),
        .init(name: "Homebrew Cache", path: "/Users/demo/Library/Caches/Homebrew", size: 2 << 30, insight: true, cleanable: true),
    ])

    /// Home folder children (`mo analyze --json ~`), in GB, for the donut and the explorer.
    static let home: MoleAnalysis = folder(MoleService.homePath, [
        ("Library", 61), ("Movies", 38), ("Developer", 27), ("Pictures", 21), ("Music", 12), ("Documents", 9),
        ("Downloads", 6), (".gradle", 5), ("Desktop", 3), (".npm", 2), (".cache", 2), ("Public", 1),
    ])

    static let library: MoleAnalysis = folder(MoleService.homePath + "/Library", [
        ("Developer", 24), ("Containers", 14), ("Application Support", 11), ("Caches", 6), ("Mail", 3),
        ("Group Containers", 2), ("Logs", 1),
    ])

    private static func folder(_ path: String, _ children: [(String, Int64)]) -> MoleAnalysis {
        MoleAnalysis(path: path, scanStatus: .complete,
                     entries: children.map { .init(name: $0.0, path: path + "/" + $0.0, size: $0.1 << 30) })
    }

    /// A `mo clean --dry-run` preview, as Mole prints it and lists it in clean-list.txt.
    static let cleanPreview = MoleService.CleanPreview(
        report: MoleReport.parse("""
        ◎ System caches need sudo, run sudo -v && mo clean --dry-run for full preview
        ➤ User essentials
          ○ User app cache · 42 items, 2.84GB dry
          ◎ Trash · skipped, grant Full Disk Access to your terminal
        ➤ Developer tools
          ⊙ Docker unused data · review with docker system df -v
        ======================================================================
        Dry run complete - no changes made
        Potential space: 6.21GB · 318 items
        ======================================================================
        """),
        list: MoleCleanList(groups: [
            ("User essentials", ["Library/Caches/com.spotify.client": 1_420, "Library/Caches/Google": 980, "Library/Logs": 440]),
            ("Developer tools", ["Library/Developer/Xcode/DerivedData": 1_310, ".npm/_cacache": 412, ".gradle/caches/build-cache-1": 260]),
            ("Browsers", ["Library/Caches/com.apple.Safari": 520, "Library/Caches/Firefox": 214]),
            ("App caches", ["Library/Caches/com.apple.Music": 330, "Library/Caches/GeoServices": 72]),
            ("Apps & utilities", ["Library/Caches/Homebrew": 180, "Library/Logs/DiagnosticReports": 70]),
        ].map { title, paths in
            MoleCleanList.Group(title: title, candidates: paths.sorted { $0.value > $1.value }.map {
                .init(path: MoleService.homePath + "/" + $0.key, bytes: Int64($0.value) * 1_000_000)
            })
        })
    )

    /// Sample data for every screen that shows numbers.
    static func fill(_ monitor: SystemMonitorService, mole: MoleService, settings: AppSettings) {
        mole.publish(analysis)
        mole.publishFolder(home, for: home.path)
        mole.publishFolder(library, for: library.path)
        mole.publishCleanPreview(cleanPreview)
        settings.showCPU = true
        settings.showRAM = true
        settings.showNet = true
        fill(monitor)
    }

    static func fill(_ monitor: SystemMonitorService) {
        let groups = ProcessGroup.build(from: processes)
        for step in 0..<SystemMonitorService.historyLength {
            _ = monitor.apply(snapshot(step: step), groups: groups)
        }
    }
}
