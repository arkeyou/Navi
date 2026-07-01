import Model
import SwiftUI

struct ScriptSelectionView: View {
    @Bindable var store: Browser

    var body: some View {
        NavigationStack {
            List {
                if store.savedScriptURLs.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Nenhum script salvo")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Você pode salvar seus scripts usando o botão 'Salvar' na tela anterior.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.savedScriptURLs, id: \.self) { url in
                        Button {
                            Task {
                                await store.send(.scriptSelected(url))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .foregroundStyle(Color.primary)
                                        .font(.body)
                                    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                                       let modificationDate = attributes[.modificationDate] as? Date {
                                        Text(modificationDate, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let url = store.savedScriptURLs[index]
                            Task {
                                await store.send(.deleteScript(url))
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Carregar Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        store.isPresentedScriptSelection = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.isPresentedScriptImporter = true
                    } label: {
                        Label("Importar", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
    }
}
