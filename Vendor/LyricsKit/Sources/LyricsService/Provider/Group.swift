import Foundation
import LyricsCore
import os.log

extension LyricsProviders {
    public final class Group: LyricsProvider {
        private static let log = OSLog(subsystem: "LyricsKit", category: "LyricsProviders.Group")
        public let providers: [LyricsProvider]

        /// Plugins run upstream of `providers`: they widen a search by
        /// producing extra requests, they never produce lyrics themselves.
        public let plugins: [LyricsSearchRequestPlugin]

        public init(
            providers: [LyricsProvider] = [],
            plugins: [LyricsSearchRequestPlugin] = []
        ) {
            self.providers = providers
            self.plugins = plugins
        }

        public func lyrics(for request: LyricsSearchRequest) -> AsyncThrowingStream<Lyrics, Error> {
            AsyncThrowingStream { continuation in
                let task = Task {
                    await withTaskGroup(of: Void.self) { taskGroup in
                        // Search the original request immediately — plugin
                        // resolution must never delay the direct providers.
                        taskGroup.addTask {
                            await self.search(request, into: continuation)
                        }
                        // Plugins widen the search; each extra request they
                        // produce is searched as soon as it resolves.
                        if !self.plugins.isEmpty {
                            taskGroup.addTask {
                                let extraRequests = await self.expand(request)
                                await withTaskGroup(of: Void.self) { extraTaskGroup in
                                    for extraRequest in extraRequests {
                                        extraTaskGroup.addTask {
                                            await self.search(extraRequest, into: continuation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        /// Run every provider for `request`, forwarding their lyrics downstream.
        private func search(
            _ request: LyricsSearchRequest,
            into continuation: AsyncThrowingStream<Lyrics, Error>.Continuation
        ) async {
            await withTaskGroup(of: Void.self) { taskGroup in
                for provider in providers {
                    taskGroup.addTask {
                        do {
                            for try await lyric in provider.lyrics(for: request) {
                                continuation.yield(lyric)
                            }
                        } catch {
                            os_log(.error, log: Self.log, "A provider in the group failed: %{private}@", String(describing: error))
                        }
                    }
                }
            }
        }

        /// Ask every plugin for extra requests to search, discarding any
        /// whose term repeats the original request or an earlier plugin's.
        private func expand(_ request: LyricsSearchRequest) async -> [LyricsSearchRequest] {
            var collectedRequests: [LyricsSearchRequest] = []
            await withTaskGroup(of: [LyricsSearchRequest].self) { taskGroup in
                for plugin in plugins {
                    taskGroup.addTask {
                        await plugin.additionalRequests(for: request)
                    }
                }
                for await pluginRequests in taskGroup {
                    collectedRequests.append(contentsOf: pluginRequests)
                }
            }
            var scheduledTerms: [LyricsSearchRequest.SearchTerm] = [request.searchTerm]
            var uniqueRequests: [LyricsSearchRequest] = []
            for candidateRequest in collectedRequests
            where !scheduledTerms.contains(candidateRequest.searchTerm) {
                scheduledTerms.append(candidateRequest.searchTerm)
                uniqueRequests.append(candidateRequest)
            }
            return uniqueRequests
        }
    }
}
