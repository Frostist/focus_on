import SwiftUI
import AppKit

struct WidgetView: View {
    @EnvironmentObject var store: TaskStore

    @State private var pulseOpacity: Double = 1.0

    private static let activeBlue = Color(red: 0.25, green: 0.55, blue: 1.0)

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                let isActive = store.currentTaskName != nil
                Circle()
                    .fill(isActive ? Self.activeBlue : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 16, height: 16)
                    .opacity(pulseOpacity)
                    .onAppear { updatePulse(active: isActive) }
                    .onChange(of: store.currentTaskName) { _ in
                        updatePulse(active: store.currentTaskName != nil)
                    }

                if let task = store.currentTaskName {
                    Text(task)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize()
                } else {
                    Text("No active task")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        // No SwiftUI gestures — drag/tap handled by WidgetContainerView at the NSView level
    }

    private func updatePulse(active: Bool) {
        if active {
            pulseOpacity = 1.0
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.4
            }
        } else {
            withAnimation(.linear(duration: 0)) {
                pulseOpacity = 1.0
            }
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
