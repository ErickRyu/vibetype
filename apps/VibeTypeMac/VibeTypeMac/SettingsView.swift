import SwiftUI
import VibeTypeCore

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView {
            modelTab
                .tabItem {
                    Label("모델", systemImage: "cpu")
                }

            aboutTab
                .tabItem {
                    Label("정보", systemImage: "info.circle")
                }
        }
        .padding()
    }

    private var modelTab: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: 16) {
            Text("Gemma 모델")
                .font(.headline)

            Picker("모델 선택", selection: $state.selectedModelID) {
                ForEach(VibeTypeModelRegistry.all) { model in
                    Text("\(model.displayName)  ·  \(formatSize(model.approxSizeBytes))")
                        .tag(model.id)
                }
            }
            .pickerStyle(.menu)

            Text(state.selectedModel.notes)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            modelStatusRow

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modelStatusRow: some View {
        HStack {
            switch state.modelState {
            case .notLoaded:
                Button("모델 다운로드 / 로드") {
                    Task { await state.ensureModelLoaded() }
                }
                .buttonStyle(.borderedProminent)
            case .downloading(let p):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: p)
                        .frame(maxWidth: .infinity)
                    Text("다운로드 중… \(Int(p * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .loading:
                ProgressView("모델 로드 중…")
            case .ready:
                Label("준비됨", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("모델 변경 적용") {
                    Task { await state.switchModel(to: state.selectedModelID) }
                }
            case .failed(let msg):
                VStack(alignment: .leading) {
                    Label("로드 실패", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Button("다시 시도") {
                        Task { await state.ensureModelLoaded() }
                    }
                }
            }
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VibeType")
                .font(.title)
                .fontWeight(.semibold)
            Text("로컬 Gemma 기반 키보드 컴패니언")
                .foregroundStyle(.secondary)
            Divider()
            Text("Core 버전: \(VibeType.version)")
                .font(.caption.monospaced())
            Text("추론은 모두 사용자 기기에서 실행됩니다. 네트워크 호출은 모델 다운로드 시에만 발생합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        return String(format: "%.1f GB", gb)
    }
}
