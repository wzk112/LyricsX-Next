import SwiftUI
import LyricsXCore
import LyricsXServices

struct SearchView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var previousQuery = ""
    @State private var previousCompleteSearch = false
    @State private var previousConfigurationKey = ""
    @State private var completeSearch = false
    @State private var results: [LyricCandidate] = []
    @State private var searching = false
    @State private var retainedPreviousResults = false
    @State private var sourceStatuses: [SourceSearchStatus] = []
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var deadline: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var trackID: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text("找到对的那一句").font(.title2.bold()); Text(searching ? "正在加载歌词，结果会逐步显示…" : "搜索多个歌词源，选择最适合当前歌曲的版本。").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("歌曲名和歌手", text: $query).textFieldStyle(.plain).onSubmit(search)
                if searching { ProgressView().controlSize(.small) }
                Button("搜索", action: search).buttonStyle(.glassProminent).disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(12).background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
            HStack(spacing: 10) {
                Toggle("完整搜索", isOn: $completeSearch).toggleStyle(.switch).controlSize(.small)
                    .onChange(of: completeSearch) { _, _ in search() }
                Text(completeSearch ? "搜索更多别名和版本，最多等待 40 秒" : "精简重复版本，每个来源最多显示 12 个")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            if !sourceStatuses.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(sourceStatuses) { status in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(status.source) · \(status.count) 个版本" + (status.isSearching ? " …" : ""))
                            if let issue = status.issue { Text(issue).foregroundStyle(.orange).lineLimit(2) }
                            else if !status.isSearching, status.count == 0 { Text("暂无结果").foregroundStyle(.tertiary) }
                        }.font(.caption2).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.foregroundStyle(.secondary)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            if results.isEmpty {
                ContentUnavailableView(searching ? "正在加载歌词" : "暂无结果", systemImage: "text.magnifyingglass", description: Text("也可以将本地 LRC 或 LRCX 文件拖入主窗口。"))
            } else {
                List(results) { candidate in
                    HStack(spacing: 14) {
                        Image(systemName: candidate.document.hasWordTiming ? "waveform" : "text.quote").font(.title3).foregroundStyle(.secondary).frame(width: 30)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.document.title.isEmpty ? "未命名歌词" : candidate.document.title).font(.headline)
                            Text("\(candidate.document.artist) · \(candidate.document.source) · \(candidate.document.lines.count) 行").font(.caption).foregroundStyle(.secondary)
                            if let first = candidate.document.lines.first(where: { !$0.text.isEmpty }) { Text(first.text).font(.caption).lineLimit(1).foregroundStyle(.tertiary) }
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            if candidate.document.hasWordTiming { searchTag("逐字") }
                            if candidate.document.hasTranslation { searchTag("双语") }
                        }
                        Button("使用") {
                            guard model.session.track?.id == trackID else { error = "歌曲已切换，请重新搜索。"; return }
                            model.session.use(candidate.document); dismiss()
                        }.buttonStyle(.glass).disabled(model.session.track == nil)
                    }.padding(.vertical, 8)
                }.listStyle(.plain)
            }
            HStack { Text("\(results.count) 个版本" + (retainedPreviousResults ? " · 包含上次搜索结果" : "")).font(.caption).foregroundStyle(.secondary); Spacer(); Button("导入本地歌词") { model.importLyrics() } }
        }.padding(26).frame(width: 760, height: 570)
            .onAppear { query = [model.session.track?.title, model.session.track?.artist].compactMap { $0 }.joined(separator: " "); trackID = model.session.track?.id; results = model.session.candidates; search() }
            .onDisappear {
                requestID = UUID(); searchTask?.cancel(); deadline?.cancel()
                searchTask = nil; deadline = nil
            }
            .onChange(of: model.session.track?.id) { _, _ in searchTask?.cancel(); deadline?.cancel(); searching = false; requestID = UUID(); sourceStatuses = []; results = []; error = "歌曲已切换，请重新搜索。" }
    }
    private static func sameVersion(_ lhs: LyricsDocument, _ rhs: LyricsDocument) -> Bool {
        guard lhs.source == rhs.source else { return false }
        if let a = lhs.providerID, let b = rhs.providerID { return a == b }
        return lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
            && lhs.lines == rhs.lines && lhs.plainText == rhs.plainText && lhs.isInstrumental == rhs.isInstrumental
    }
    private func searchTag(_ title: String) -> some View {
        Text(title).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.quaternary.opacity(0.65), in: .capsule)
    }
    private func search() {
        searchTask?.cancel(); deadline?.cancel()
        let id = UUID(); requestID = id; searching = true; error = nil; sourceStatuses = []
        // Keep the last completed versions visible while retrying a source.
        // A transport failure must not make known results disappear.
        let configuration = model.preferences.sourceConfigurationReader.read()
        if trackID != model.session.track?.id || previousQuery != query || previousCompleteSearch != completeSearch
            || previousConfigurationKey != configuration.selectionKey { results = [] }
        retainedPreviousResults = !results.isEmpty
        previousQuery = query
        previousCompleteSearch = completeSearch
        previousConfigurationKey = configuration.selectionKey
        let track = model.session.track ?? Track(playerID: "search", playerName: "搜索", title: query)
        trackID = model.session.track?.id
        searchTask = Task {
            do {
                for try await result in model.store.search(track: track, keyword: query, complete: completeSearch, onSourceUpdate: { status in
                    Task { @MainActor in
                        guard requestID == id else { return }
                        if let index = sourceStatuses.firstIndex(where: { $0.source == status.source }) { sourceStatuses[index] = status }
                        else { sourceStatuses.append(status) }
                        let order = model.preferences.sourceOrder
                        sourceStatuses.sort { (order.firstIndex(of: $0.source) ?? 99) < (order.firstIndex(of: $1.source) ?? 99) }
                    }
                }) {
                    guard !Task.isCancelled, requestID == id else { return }
                    if let index = results.firstIndex(where: { $0.id == result.id || Self.sameVersion($0.document, result.document) }) {
                        results[index] = result
                    } else { results.append(result) }
                    results = configuration.orderedManualResults(results, complete: completeSearch)
                }
            } catch { if !Task.isCancelled, requestID == id { self.error = error.localizedDescription } }
            if requestID == id { searching = false; deadline?.cancel() }
        }
        deadline = Task {
            do { try await Task.sleep(for: completeSearch ? .seconds(44) : .seconds(22)) } catch { return }
            guard requestID == id else { return }; searchTask?.cancel(); searching = false
            if results.isEmpty { error = "歌词源响应超时，请重试。" }
        }
    }
}

struct LibraryView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: LyricsCache.Entry?
    private var filtered: [LyricsCache.Entry] { model.library.filter { query.isEmpty || ($0.track.title + $0.track.artist).localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("歌词资料库").font(.title2.bold()); Text("\(model.library.count) 首").foregroundStyle(.secondary); if model.libraryLoading { ProgressView().controlSize(.small) }; Spacer(); Button("完成") { dismiss() } }
            TextField("搜索已保存的歌曲", text: $query).textFieldStyle(.roundedBorder)
            HSplitView {
                List(filtered) { entry in
                    Button { selected = entry } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.track.title).font(.headline)
                            Text(entry.track.artist + " · " + entry.url.pathExtension.uppercased()).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                    }.buttonStyle(.plain)
                }.frame(minWidth: 240).listStyle(.plain)
                ScrollView {
                    if let selected {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(selected.track.title).font(.title2.bold())
                            Text(LyricsCodec.export(selected.document, plain: true)).font(.system(size: 15)).lineSpacing(8).textSelection(.enabled)
                            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([selected.url]) }
                            if model.session.track != nil { Button("用于当前歌曲") { model.session.use(selected.document); dismiss() }.buttonStyle(.glass) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    } else { ContentUnavailableView("选择一首歌曲", systemImage: "text.book.closed", description: Text("这里直接显示现有缓存文件夹中的歌词。")) }
                }.frame(minWidth: 310)
            }
            HStack { Image(systemName: "folder"); Text(model.preferences.directory.path).lineLimit(1).truncationMode(.middle); Spacer(); Button("更改…") { model.chooseCacheDirectory() } }.font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 740, height: 510).task { model.loadLibrary() }
            .onDisappear { selected = nil; model.unloadLibrary() }
    }
}
