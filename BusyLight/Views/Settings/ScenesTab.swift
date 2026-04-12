import SwiftUI

struct ScenesTab: View {
    @Environment(\.undoManager) private var undoManager
    @State private var settings = AppSettings.shared
    @State private var undoHandler = SceneUndoHandler()
    @State private var availableScenes: [HAScene] = []
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var selectedItemId: String?
    @FocusState private var focusedNameIndex: Int?
    @State private var nameEditSnapshotIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with refresh button
            HStack {
                Text("Menu Items")
                    .font(.headline)

                Spacer()

                if let error = fetchError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(1)
                }

                if isFetching {
                    ProgressView().controlSize(.small)
                }

                Button("Refresh Scenes from Home Assistant") {
                    fetchScenes()
                }
                .controlSize(.small)
                .disabled(isFetching || settings.haBaseURL.isEmpty || settings.haToken.isEmpty)
            }

            // Configured scene list
            if settings.menuItems.isEmpty {
                Group {
                    if settings.haBaseURL.isEmpty || settings.haToken.isEmpty {
                        Text("Connect to Home Assistant in the Home Assistant tab to get started.")
                    } else {
                        Text("No scenes configured. Click + below to add scenes from Home Assistant.")
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(selection: $selectedItemId) {
                    ForEach(Array(settings.menuItems.enumerated()), id: \.element.id) { index, item in
                        menuItemRow(item, at: index)
                            .tag(item.id)
                    }
                    .onMove(perform: moveItems)
                }
                .listStyle(.bordered)
                .onDeleteCommand(perform: removeSelectedItem)
                .onChange(of: focusedNameIndex) { _, _ in
                    nameEditSnapshotIndex = nil
                }
            }

            // +/- toolbar buttons
            HStack(spacing: 0) {
                // "+" button with popup menu
                Menu {
                    Button("Add Divider") {
                        undoHandler.saveSnapshot(actionName: "Add Divider")
                        settings.menuItems.append(.newDivider())
                    }

                    Divider()

                    if availableScenes.isEmpty {
                        Text("Refresh scenes to see available options")
                    } else {
                        ForEach(availableScenes) { scene in
                            let alreadyAdded = settings.scenes.contains(where: { $0.entityId == scene.entityId })
                            Button(scene.friendlyName) {
                                addScene(scene)
                            }
                            .disabled(alreadyAdded)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)

                // "-" button
                Button(action: removeSelectedItem) {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedItemId == nil)

                Spacer()
            }
        }
        .padding()
        .onAppear {
            undoHandler.undoManager = undoManager
            // Auto-fetch scenes when switching to this tab, if HA is configured
            if !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty {
                fetchScenes()
            }
        }
    }

    @ViewBuilder
    private func menuItemRow(_ item: MenuListItem, at index: Int) -> some View {
        switch item {
        case .scene(let scene):
            HStack(spacing: 8) {
                EmojiPickerButton(emoji: bindingForEmoji(at: index))

                TextField("Display Name", text: bindingForName(at: index))
                    .focused($focusedNameIndex, equals: index)
                    .frame(minWidth: 120, maxWidth: 200)

                Text(scene.entityId)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(scene.entityId)

                Spacer()

                ShortcutRecorderView(sceneEntityId: scene.entityId) {
                    undoHandler.saveSnapshot(actionName: "Set Shortcut")
                }
            }
        case .divider:
            HStack {
                Spacer()
                Text("\u{2014}\u{2014}\u{2014}  Divider  \u{2014}\u{2014}\u{2014}")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(minHeight: 28)
        }
    }

    private func bindingForEmoji(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < settings.menuItems.count,
                      case .scene(let scene) = settings.menuItems[index] else { return "" }
                return scene.emoji
            },
            set: { newValue in
                guard index < settings.menuItems.count,
                      case .scene(var scene) = settings.menuItems[index] else { return }
                undoHandler.saveSnapshot(actionName: "Change Emoji")
                scene.emoji = newValue
                settings.menuItems[index] = .scene(scene)
            }
        )
    }

    private func bindingForName(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < settings.menuItems.count,
                      case .scene(let scene) = settings.menuItems[index] else { return "" }
                return scene.displayName
            },
            set: { newValue in
                guard index < settings.menuItems.count,
                      case .scene(var scene) = settings.menuItems[index] else { return }
                if nameEditSnapshotIndex != index {
                    undoHandler.saveSnapshot(actionName: "Change Name")
                    nameEditSnapshotIndex = index
                }
                scene.displayName = newValue
                settings.menuItems[index] = .scene(scene)
            }
        )
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        undoHandler.saveSnapshot(actionName: "Reorder")
        settings.menuItems.move(fromOffsets: source, toOffset: destination)
    }

    private func removeSelectedItem() {
        guard let selectedId = selectedItemId,
              let index = settings.menuItems.firstIndex(where: { $0.id == selectedId }) else { return }
        undoHandler.saveSnapshot(actionName: "Remove Item")
        settings.menuItems.remove(at: index)
        selectedItemId = nil
    }

    private func addScene(_ haScene: HAScene) {
        // Don't add duplicates
        let alreadyAdded = settings.scenes.contains(where: { $0.entityId == haScene.entityId })
        guard !alreadyAdded else {
            fetchError = "Scene already added"
            return
        }

        let sceneItem = SceneItem(
            entityId: haScene.entityId,
            emoji: "\u{1F3AC}",
            displayName: haScene.friendlyName
        )
        undoHandler.saveSnapshot(actionName: "Add Scene")
        settings.menuItems.append(.scene(sceneItem))
    }

    private func fetchScenes() {
        isFetching = true
        fetchError = nil
        Task {
            do {
                availableScenes = try await HomeAssistantService.shared.fetchScenes(
                    baseURL: settings.haBaseURL, token: settings.haToken)
            } catch {
                fetchError = error.localizedDescription
            }
            isFetching = false
        }
    }
}
