import SwiftUI
import AppKit

// Phase 3에서 첫 실행 시 Accessibility 권한 안내에 사용.
// v0.1 배포 전에 first-launch 플로우에서 호출.
struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("VibeType에 오신 것을 환영합니다")
                .font(.title)
                .fontWeight(.semibold)

            Text("선택한 텍스트를 ⌥Space로 AI가 다듬어 드립니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Accessibility 권한 필요", systemImage: "lock.shield")
                Text("VibeType은 다른 앱의 선택 텍스트를 읽고 결과로 교체하기 위해 Accessibility 권한이 필요합니다. 권한 없이는 키보드 단축키 기능이 동작하지 않습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("나중에") {
                    onFinish()
                }
                Button("System Settings 열기") {
                    openAccessibilitySettings()
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 480)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
