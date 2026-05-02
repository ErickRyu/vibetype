import SwiftUI
import VibeTypeCore
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView {
            whisperTab
                .tabItem {
                    Label("받아쓰기", systemImage: "mic")
                }

            modelTab
                .tabItem {
                    Label("후처리 LLM", systemImage: "cpu")
                }

            shortcutsTab
                .tabItem {
                    Label("단축키", systemImage: "command")
                }

            aboutTab
                .tabItem {
                    Label("정보", systemImage: "info.circle")
                }
        }
        .padding()
    }

    private var whisperTab: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: 16) {
            Text("Whisper STT 모델")
                .font(.headline)

            Picker("모델 선택", selection: $state.selectedWhisperID) {
                ForEach(VibeTypeWhisperRegistry.all) { model in
                    Text("\(model.displayName)  ·  \(formatSize(model.approxSizeBytes))")
                        .tag(model.id)
                }
            }
            .pickerStyle(.menu)

            Text(state.selectedWhisper.notes)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            whisperStatusRow

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whisperStatusRow: some View {
        HStack {
            switch state.whisperState {
            case .notLoaded:
                Button("Whisper 모델 다운로드 / 로드") {
                    Task { await state.ensureWhisperLoaded() }
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
                ProgressView("Whisper 모델 로드 중… (CoreML 컴파일, 첫 회 5분 소요)")
            case .ready:
                Label("준비됨", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("모델 변경 적용") {
                    Task { await state.switchWhisper(to: state.selectedWhisperID) }
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
                        Task { await state.ensureWhisperLoaded() }
                    }
                }
            }
        }
    }

    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 받아쓰기 (메인) — Fn 키 push-to-talk
            VStack(alignment: .leading, spacing: 8) {
                Text("받아쓰기")
                    .font(.headline)
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fn 키(또는 🌐 Globe 키)를 **누르고 있는 동안 녹음**, 떼면 변환되어 포커스된 앱에 입력됩니다.")
                        Text("⚠️ macOS의 \"Fn 키 누르기\" 기능과 충돌 시: System Settings → Keyboard → \"Press 🌐 key to\"를 \"Do Nothing\"으로 변경해 주세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.tint)
                }
                .font(.callout)

                Text("선택 — 추가 단축키로도 토글하기:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Form {
                    KeyboardShortcuts.Recorder("받아쓰기 토글 (선택)", name: .dictate)
                }
            }

            Divider()

            // 텍스트 다듬기 (보너스)
            VStack(alignment: .leading, spacing: 8) {
                Text("텍스트 다듬기 (보너스)")
                    .font(.headline)
                Text("어떤 앱에서든 텍스트를 선택한 뒤 아래 단축키를 누르면 결과로 교체됩니다. 디폴트 단축키 미할당 — 원하는 키를 직접 매핑하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Form {
                    ForEach(TextAction.allCases, id: \.self) { action in
                        KeyboardShortcuts.Recorder(action.displayNameKo, name: HotkeyManager.shortcutName(for: action))
                    }
                }
            }
            Spacer()

            Group {
                if AccessibilityService.hasPermission {
                    Label("Accessibility 권한 허용됨", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Accessibility 권한 필요", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("System Settings 열기") {
                            AccessibilityService.requestPermissionIfNeeded()
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
