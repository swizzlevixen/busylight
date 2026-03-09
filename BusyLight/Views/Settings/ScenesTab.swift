import SwiftUI

struct ScenesTab: View {
    @State private var settings = AppSettings.shared
    @State private var availableScenes: [HAScene] = []
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var selectedHASceneId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Fetch & Add section
            HStack {
                Button("Fetch Scenes from HA") {
                    fetchScenes()
                }
                .disabled(isFetching || settings.haBaseURL.isEmpty || settings.haToken.isEmpty)

                if isFetching {
                    ProgressView().controlSize(.small)
                }

                if let error = fetchError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if !availableScenes.isEmpty {
                HStack {
                    Picker("Add Scene:", selection: $selectedHASceneId) {
                        Text("Select\u{2026}").tag(nil as String?)
                        ForEach(availableScenes) { scene in
                            Text(scene.friendlyName).tag(scene.entityId as String?)
                        }
                    }
                    .frame(maxWidth: 250)

                    Button("Add") {
                        addSelectedScene()
                    }
                    .disabled(selectedHASceneId == nil)

                    Spacer()

                    Button("Add Divider") {
                        settings.menuItems.append(.newDivider())
                    }
                }
            }

            Divider()

            // Configured scene list
            if settings.menuItems.isEmpty {
                Text("No scenes configured. Fetch scenes from Home Assistant and add them above.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(Array(settings.menuItems.enumerated()), id: \.element.id) { index, item in
                        menuItemRow(item, at: index)
                    }
                    .onMove(perform: moveItems)
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func menuItemRow(_ item: MenuListItem, at index: Int) -> some View {
        switch item {
        case .scene(let scene):
            HStack(spacing: 8) {
                TextField("", text: bindingForEmoji(at: index))
                    .frame(width: 40)
                    .multilineTextAlignment(.center)

                TextField("Display Name", text: bindingForName(at: index))
                    .frame(minWidth: 120)

                Text(scene.entityId)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
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

    private func deleteItems(at offsets: IndexSet) {
        settings.menuItems.remove(atOffsets: offsets)
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

    private func addSelectedScene() {
        guard let entityId = selectedHASceneId,
              let haScene = availableScenes.first(where: { $0.entityId == entityId }) else { return }

        // Don't add duplicates
        let alreadyAdded = settings.scenes.contains(where: { $0.entityId == entityId })
        guard !alreadyAdded else {
            fetchError = "Scene already added"
            return
        }

        let sceneItem = SceneItem(
            entityId: haScene.entityId,
            emoji: "🎬",
            displayName: haScene.friendlyName
        )
        settings.menuItems.append(.scene(sceneItem))
        selectedHASceneId = nil
    }
}
