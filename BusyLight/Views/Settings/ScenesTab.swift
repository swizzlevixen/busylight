import SwiftUI

struct ScenesTab: View {
    @State private var settings = AppSettings.shared
    @State private var availableScenes: [HAScene] = []
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var selectedItemId: String?

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
                Text("No scenes configured. Click + below to add scenes from Home Assistant.")
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
            }

            // +/- toolbar buttons
            HStack(spacing: 0) {
                // "+" button with popup menu
                Menu {
                    Button("Add Divider") {
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
                    .frame(minWidth: 100, maxWidth: 140)

                Text(scene.entityId)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                ShortcutRecorderView(sceneEntityId: scene.entityId)
            }
        case .divider:
            HStack {
                Text("--- Divider ---")
                    .foregroundStyle(.secondary)
                    .italic()
                Spacer()
            }
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
                scene.displayName = newValue
                settings.menuItems[index] = .scene(scene)
            }
        )
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        settings.menuItems.move(fromOffsets: source, toOffset: destination)
    }

    private func removeSelectedItem() {
        guard let selectedId = selectedItemId,
              let index = settings.menuItems.firstIndex(where: { $0.id == selectedId }) else { return }
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
