import AppKit
import Foundation

/// Passive Apple Events must address one running process. A name/bundle target
/// can relaunch the app if it exits after a running check, even within a script.
enum RunningPlayerScript {
    @MainActor static func processIdentifier(for bundleID: String) -> Int32? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { !$0.isTerminated }?.processIdentifier
    }

    static func runJavaScript(bundleID: String, body: String, arguments: [String] = [],
                              timeout: Double = 4) async throws -> ProcessRunner.Output? {
        guard let pid = await processIdentifier(for: bundleID) else { return nil }
        return try await runJavaScript(processIdentifier: pid, bundleID: bundleID, body: body, arguments: arguments, timeout: timeout)
    }

    static func runJavaScript(processIdentifier: Int32, bundleID: String? = nil, body: String, arguments: [String] = [],
                              timeout: Double = 4) async throws -> ProcessRunner.Output {
        let music = bundleID == "com.apple.Music"
        let source = """
        \(music ? MusicProcessScript.source : "")
        function run(argv) {
          const app = \(music ? "musicProcess(\(processIdentifier))" : "Application(\(processIdentifier))");
          \(body)
        }
        """
        return try await ProcessRunner.run("/usr/bin/osascript",
            arguments: ["-l", "JavaScript", "-e", source] + arguments, timeout: timeout)
    }
}
