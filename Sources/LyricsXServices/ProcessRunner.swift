import Foundation
import Darwin

/// Blocking process APIs run outside the UI executor. Files avoid stdout/stderr pipe deadlocks.
enum ProcessRunner {
    struct Output: Sendable { var data: Data; var error: String; var status: Int32 }
    static func run(_ executable: String, arguments: [String], timeout: Double = 4) async throws -> Output {
        let execution = Execution()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LyricsX-" + UUID().uuidString)
                    do {
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        defer { try? FileManager.default.removeItem(at: directory) }
                        let out = directory.appendingPathComponent("stdout"), err = directory.appendingPathComponent("stderr")
                        FileManager.default.createFile(atPath: out.path, contents: nil)
                        FileManager.default.createFile(atPath: err.path, contents: nil)
                        let outHandle = try FileHandle(forWritingTo: out)
                        defer { try? outHandle.close() }
                        let errHandle = try FileHandle(forWritingTo: err)
                        defer { try? errHandle.close() }
                        let process = Process(); process.executableURL = URL(fileURLWithPath: executable)
                        process.arguments = arguments; process.standardOutput = outHandle; process.standardError = errHandle
                        try execution.launch(process)
                        let timer = DispatchWorkItem { execution.cancel() }
                        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
                        process.waitUntilExit(); timer.cancel()
                        if execution.isCancelled { throw CancellationError() }
                        let reader = try FileHandle(forReadingFrom: out)
                        defer { try? reader.close() }
                        let data = try reader.read(upToCount: 12_000_000) ?? Data()
                        let errorReader = try FileHandle(forReadingFrom: err)
                        defer { try? errorReader.close() }
                        let errorData = try errorReader.read(upToCount: 4096) ?? Data()
                        continuation.resume(returning: Output(data: data, error: String(decoding: errorData.prefix(4096), as: UTF8.self), status: process.terminationStatus))
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { execution.cancel() }
    }
    // The lock protects cancellation and process launch as a single operation.
    private final class Execution: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false
        var isCancelled: Bool { lock.withLock { cancelled } }
        func launch(_ process: Process) throws {
            try lock.withLock {
                if cancelled { throw CancellationError() }
                self.process = process; try process.run()
            }
        }
        func cancel() {
            lock.withLock {
                cancelled = true
                if let process, process.isRunning {
                    process.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    }
                }
            }
        }
    }
}
