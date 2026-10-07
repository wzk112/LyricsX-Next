import SwiftUI
import LyricsXCore
import LyricsXServices

struct SearchView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var controller: LyricsSearchController
    init(model: AppModel, controller: LyricsSearchController? = nil) {
        self.model = model
        _controller = State(initialValue: controller ?? LyricsSearchController(model: model))
    }
    var body: some View {
        @Bindable var search = controller
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text("搜索歌词").font(.title2.bold()); Text(controller.searching ? "正在加载歌词，结果会逐步显示…" : "先预览，再应用；选好后点击“完成”。").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("歌曲名和歌手", text: $search.query).textFieldStyle(.plain).onSubmit { controller.search() }
                ProgressView().controlSize(.small).opacity(controller.searching ? 1 : 0)
                    .frame(width: 16, height: 16).accessibilityHidden(!controller.searching)
                Button("搜索", action: controller.search).buttonStyle(.glassProminent).disabled(controller.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(12).background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
            HStack(spacing: 10) {
                Toggle("完整搜索", isOn: $search.completeSearch).toggleStyle(.switch).controlSize(.small)
                    .onChange(of: controller.completeSearch) { _, _ in controller.search() }
                Text(controller.completeSearch ? "搜索更多别名和版本，最多等待 40 秒" : "精简重复版本，每个来源最多显示 12 个")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if controller.sourceStatuses.isEmpty {
                        Text(controller.searching ? "正在连接歌词源…" : " ")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(controller.sourceStatuses) { status in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(status.source) · \(status.count) 个版本" + (status.isSearching ? " …" : ""))
                                    if let issue = status.issue { Text(issue).foregroundStyle(.orange).lineLimit(2) }
                                    else if !status.isSearching, status.count == 0 { Text("暂无结果").foregroundStyle(.tertiary) }
                                }.font(.caption2).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }.frame(height: 38, alignment: .top)
                Text(controller.error ?? " ").font(.caption).foregroundStyle(.orange)
                    .opacity(controller.error == nil ? 0 : 1).frame(height: 16, alignment: .leading)
            }.frame(height: 58, alignment: .top)
            HStack(spacing: 16) {
                Group {
                    if controller.results.isEmpty {
                        ContentUnavailableView(controller.searching ? "正在加载歌词" : "暂无结果", systemImage: "text.magnifyingglass", description: Text("也可以导入本地 LRC 或 LRCX 文件。"))
                    } else {
                        List(controller.results) { candidate in
                            let applied = model.session.document.map { $0.representsSameVersion(as: candidate.document) } == true
                            HStack(spacing: 10) {
                                Image(systemName: candidate.document.hasWordTiming ? "waveform" : "text.quote")
                                    .foregroundStyle(.secondary).frame(width: 22)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(candidate.document.title.isEmpty ? "未命名歌词" : candidate.document.title).font(.headline).lineLimit(2)
                                    Text("\(candidate.document.artist) · \(candidate.document.source) · \(candidate.document.isSynced ? String(candidate.document.lines.count) + " 行" : "纯文本")")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    HStack(spacing: 5) {
                                        if candidate.document.source == AppleMusicLyricsSource.name { searchTag("歌曲内嵌") }
                                        if AppleMusicCloudLyricsSource.isCloudSource(candidate.document.source) { searchTag("云端") }
                                        if !candidate.document.isSynced && !candidate.document.isInstrumental { searchTag("纯文本") }
                                        if candidate.document.hasWordTiming { searchTag("逐字") }
                                        if candidate.document.hasTranslation { searchTag("双语") }
                                    }
                                    if let first = candidate.document.lines.first(where: { !$0.text.isEmpty })?.text
                                        ?? candidate.document.plainText?.split(separator: "\n").first.map(String.init) {
                                        Text(first).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 6) {
                                    Button("预览") { controller.preview(candidate) }
                                        .accessibilityLabel("预览《" + candidate.document.title + "》，" + candidate.document.source)
                                        .disabled(controller.retainedPreviousResults)
                                        .buttonStyle(.glass)
                                    if applied {
                                        Label("已应用", systemImage: "checkmark.circle.fill")
                                            .font(.caption2).foregroundStyle(Color.accentColor)
                                    }
                                }.frame(width: 72, alignment: .trailing)
                            }.padding(.vertical, 8)
                                .contentShape(.rect).onTapGesture { controller.preview(candidate) }
                                .accessibilityElement(children: .contain)
                                .listRowBackground(controller.previewCandidate?.id == candidate.id ? Color.accentColor.opacity(0.08) : .clear)
                        }.listStyle(.plain)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 12) {
                    SearchLyricPreview(model: model, document: controller.previewCandidate?.document ?? model.session.document,
                        isPreview: controller.previewCandidate != nil)
                    Button(controller.previewIsApplied ? "已应用当前歌词" : "应用当前歌词", action: controller.applyPreview)
                        .buttonStyle(.glassProminent).disabled(!controller.canApplyPreview)
                    Text(controller.previewIsApplied ? "已应用，仍可继续预览其他版本。" : "预览不会替换或保存正式歌词。")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let issue = model.session.persistenceError {
                        Text(issue).font(.caption2).foregroundStyle(.orange)
                    }
                }.frame(width: 290)

            }
            HStack { Text("\(controller.results.count) 个版本" + (controller.retainedPreviousResults ? " · 包含上次搜索结果" : "")).font(.caption).foregroundStyle(.secondary); Spacer(); Button("导入本地歌词") { model.importLyrics() } }
        }.padding(26).frame(width: 900, height: 620)
            .onAppear { controller.open() }
            .onDisappear { controller.cancel() }
            .onChange(of: model.session.trackRevision) { _, _ in controller.trackChanged() }
            .onChange(of: model.preferences.sourceSelectionKey) { _, _ in controller.search() }
    }
    private func searchTag(_ title: String) -> some View {
        Text(title).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.quaternary.opacity(0.65), in: .capsule)
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
                            if model.session.track != nil { Button("用于当前歌曲") { model.applyLyrics(selected.document, forTrackID: model.session.track?.id); dismiss() }.buttonStyle(.glass) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    } else { ContentUnavailableView("选择一首歌曲", systemImage: "text.book.closed", description: Text("这里直接显示现有缓存文件夹中的歌词。")) }
                }.frame(minWidth: 310)
            }
            HStack { Image(systemName: "folder"); Text(model.preferences.directory.path).lineLimit(1).truncationMode(.middle); Spacer(); Button("更改…") { model.chooseCacheDirectory() } }.font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 740, height: 510).task { model.loadLibrary() }
            .onDisappear { selected = nil; model.unloadLibrary() }
    }
}
