import Foundation
import Darwin
import LyricsXCore

/// Passive, local-only JSONL transport. All mutable state is serialized on MainActor.
@MainActor final class FlexbarServer {
    enum Failure: Error, LocalizedError {
        case unsafePath, pathTooLong, occupied, system(Int32)
        var errorDescription: String? {
            switch self {
            case .unsafePath: "Flexbar 连接目录或文件的权限不安全。"
            case .pathTooLong: "Flexbar 连接路径过长。"
            case .occupied: "另一个 LyricsX Next 实例已提供 Flexbar 连接。"
            case .system(let code): "Flexbar 连接失败：\(String(cString: strerror(code)))"
            }
        }
    }
    static let maximumConnections = 4
    static let maximumFrameBytes = 65_536
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LyricsX Next/Flexbar/bridge.sock")
    }
    private final class Client {
        let fd: Int32
        var reader: DispatchSourceRead?
        var writer: DispatchSourceWrite?
        var input = Data()
        var subscribed = false
        var countedSubscriber = false
        var output: Data?
        var offset = 0
        var latest: Data?
        var handshakeTimeout: DispatchWorkItem?
        init(fd: Int32) { self.fd = fd }
    }
    let socketURL: URL
    private var listener: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clients: [Int32: Client] = [:]
    private var ownedInode: ino_t?
    private var snapshot: Data?
    private var generation: UInt64 = 0
    private let handshakeSeconds: Double
    private(set) var subscriberCount = 0
    var onSubscriberCount: ((Int) -> Void)?
    var onFirstSnapshot: (() -> FlexbarSnapshot?)?
    var isRunning: Bool { listener >= 0 }
    var connectionCount: Int { clients.count }
    var bufferedOutputBytes: Int { clients.values.reduce(0) { $0 + ($1.output?.count ?? 0) + ($1.latest?.count ?? 0) } }

    init(socketURL: URL = FlexbarServer.defaultURL, handshakeSeconds: Double = 5) {
        self.socketURL = socketURL; self.handshakeSeconds = handshakeSeconds
    }

    func start() throws {
        guard !isRunning else { return }
        let path = socketURL.path
        var address = sockaddr_un()
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { throw Failure.pathTooLong }
        let directory = socketURL.deletingLastPathComponent()
        var info = stat()
        let appDirectory = directory.deletingLastPathComponent()
        if appDirectory.lastPathComponent == "LyricsX Next", lstat(appDirectory.path, &info) == 0 {
            guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFDIR else { throw Failure.unsafePath }
        }
        if lstat(directory.path, &info) == 0 {
            guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFDIR else { throw Failure.unsafePath }
        } else {
            guard errno == ENOENT else { throw Failure.system(errno) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        guard chmod(directory.path, 0o700) == 0 else { throw Failure.system(errno) }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: Array(path.utf8) + [0])
        }
        if lstat(path, &info) == 0 {
            guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK else { throw Failure.unsafePath }
            let probe = socket(AF_UNIX, SOCK_STREAM, 0)
            guard probe >= 0 else { throw Failure.system(errno) }
            prepare(probe)
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(probe, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            let code = errno
            close(probe)
            guard result < 0, code == ECONNREFUSED else { throw Failure.occupied }
            // Recheck identity before removing only this user's stale socket.
            var current = stat()
            guard lstat(path, &current) == 0, current.st_ino == info.st_ino, current.st_uid == getuid(),
                  current.st_mode & S_IFMT == S_IFSOCK else { throw Failure.unsafePath }
            guard unlink(path) == 0 else { throw Failure.system(errno) }
        } else if errno != ENOENT { throw Failure.system(errno) }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.system(errno) }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { let code = errno; close(fd); throw Failure.system(code) }
        guard lstat(path, &info) == 0 else { close(fd); throw Failure.system(errno) }
        ownedInode = info.st_ino
        guard chmod(path, 0o600) == 0, listen(fd, Int32(Self.maximumConnections)) == 0 else {
            let code = errno; close(fd); removeOwnedSocket(); throw Failure.system(code)
        }
        prepare(fd)
        listener = fd
        generation &+= 1
        let token = generation
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { guard let self, self.generation == token, self.listener == fd else { return }; self.acceptClients() }
        }
        source.setCancelHandler { close(fd) }
        acceptSource = source; source.resume()
    }

    func stop() {
        acceptSource?.cancel(); acceptSource = nil
        generation &+= 1; listener = -1
        for fd in Array(clients.keys) { disconnect(fd) }
        snapshot = nil
        removeOwnedSocket()
    }

    private func removeOwnedSocket() {
        guard let ownedInode else { return }
        var info = stat()
        if lstat(socketURL.path, &info) == 0, info.st_ino == ownedInode,
           info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK { _ = unlink(socketURL.path) }
        self.ownedInode = nil
    }

    private func prepare(_ fd: Int32) {
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        var enabled: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
    }

    private func acceptClients() {
        guard listener >= 0 else { return }
        while true {
            let fd = accept(listener, nil, nil)
            guard fd >= 0 else { return }
            guard clients.count < Self.maximumConnections else { close(fd); continue }
            prepare(fd)
            let client = Client(fd: fd)
            clients[fd] = client
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
            source.setEventHandler { [weak self, weak client] in
                MainActor.assumeIsolated {
                    guard let self, let client, self.clients[fd] === client else { return }; self.readClient(fd)
                }
            }
            source.setCancelHandler { close(fd) }
            client.reader = source; source.resume()
            let timeout = DispatchWorkItem { [weak self, weak client] in
                MainActor.assumeIsolated {
                    guard let self, let client, self.clients[fd] === client, !client.subscribed else { return }
                    self.disconnect(fd)
                }
            }
            client.handshakeTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + handshakeSeconds, execute: timeout)
        }
    }

    private struct Subscription: Decodable { let version: Int; let kind: String; let clientTime: Double?; let nonce: String? }
    private struct ClockSync: Encodable {
        let version = 1
        let kind = "clockSync"
        let echoClientTime: Double
        let serverUptime: Double
        let nonce: String?
    }
    private func readClient(_ fd: Int32) {
        guard let client = clients[fd] else { return }
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = read(fd, &bytes, bytes.count)
            if count < 0 { if errno == EINTR { continue }; if errno == EAGAIN || errno == EWOULDBLOCK { return }; disconnect(fd); return }
            if count == 0 { disconnect(fd); return }
            client.input.append(contentsOf: bytes.prefix(count))
            while let end = client.input.firstIndex(of: 10) {
                let frame = client.input.prefix(upTo: end)
                guard frame.count <= Self.maximumFrameBytes,
                      let request = try? JSONDecoder().decode(Subscription.self, from: Data(frame)),
                      request.version == 1, request.kind == "subscribe", !client.subscribed,
                      request.clientTime?.isFinite != false, (request.nonce?.utf8.count ?? 0) <= 128 else { disconnect(fd); return }
                client.input.removeSubrange(...end)
                client.subscribed = true
                client.handshakeTimeout?.cancel(); client.handshakeTimeout = nil
                if let clientTime = request.clientTime,
                   var sync = try? JSONEncoder().encode(ClockSync(echoClientTime: clientTime,
                       serverUptime: ProcessInfo.processInfo.systemUptime, nonce: request.nonce)) {
                    sync.append(10); enqueue(sync, client: client)
                    // A clock response must not sit behind backpressure with an
                    // obsolete send timestamp. New sockets normally write it immediately.
                    guard clients[fd] === client, client.output == nil else { disconnect(fd); return }
                }
                client.countedSubscriber = true
                subscriberCount += 1; onSubscriberCount?(subscriberCount)
                if let initial = onFirstSnapshot?(), let encoded = try? JSONEncoder().encode(initial),
                   encoded.count <= Self.maximumFrameBytes {
                    var frame = encoded; frame.append(10); snapshot = frame; enqueue(frame, client: client)
                }
                else if let snapshot { enqueue(snapshot, client: client) }
            }
            guard client.input.count <= Self.maximumFrameBytes else { disconnect(fd); return }
        }
    }

    func publish(_ value: FlexbarSnapshot) {
        guard let encoded = try? JSONEncoder().encode(value), encoded.count <= Self.maximumFrameBytes else { return }
        var frame = encoded; frame.append(10); snapshot = frame
        for client in clients.values where client.subscribed { enqueue(frame, client: client) }
    }

    private func enqueue(_ frame: Data, client: Client) {
        if client.output == nil { client.output = frame; client.offset = 0 }
        else { client.latest = frame }
        flush(client)
    }

    private func flush(_ client: Client) {
        guard clients[client.fd] === client else { return }
        while let output = client.output {
            let count = output.withUnsafeBytes { buffer in
                write(client.fd, buffer.baseAddress!.advanced(by: client.offset), output.count - client.offset)
            }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK { watchWritable(client); return }
                if errno == EINTR { continue }
                disconnect(client.fd); return
            }
            guard count > 0 else { disconnect(client.fd); return }
            client.offset += count
            if client.offset == output.count { client.output = client.latest; client.latest = nil; client.offset = 0 }
        }
        client.writer?.cancel(); client.writer = nil
    }

    private func watchWritable(_ client: Client) {
        guard client.writer == nil else { return }
        // Each DispatchSource owns a separate descriptor until its cancellation
        // completes, including writers cancelled by a previous successful flush.
        let watchedFD = dup(client.fd)
        guard watchedFD >= 0 else { disconnect(client.fd); return }
        _ = fcntl(watchedFD, F_SETFD, FD_CLOEXEC)
        let source = DispatchSource.makeWriteSource(fileDescriptor: watchedFD, queue: .main)
        source.setCancelHandler { close(watchedFD) }
        source.setEventHandler { [weak self, weak client] in
            MainActor.assumeIsolated { if let client { self?.flush(client) } }
        }
        client.writer = source; source.resume()
    }

    private func disconnect(_ fd: Int32) {
        guard let client = clients.removeValue(forKey: fd) else { return }
        client.handshakeTimeout?.cancel(); client.writer?.cancel(); client.reader?.cancel()
        if client.countedSubscriber { subscriberCount -= 1; onSubscriberCount?(subscriberCount) }
    }

    isolated deinit { stop() }
}
