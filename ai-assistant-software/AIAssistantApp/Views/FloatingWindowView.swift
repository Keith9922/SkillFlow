import SwiftUI

struct FloatingWindowView: View {
    @StateObject private var viewModel = AssistantViewModel()
    @State private var isExpanded = true
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // 毛玻璃背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            // 边框发光效果
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            VStack(spacing: 0) {
                // 标题栏
                WindowHeader(isExpanded: $isExpanded)
                
                if isExpanded {
                    // 主内容区
                    MainContentView(viewModel: viewModel, isDragging: $isDragging)
                }
            }
        }
        .frame(width: 380, height: isExpanded ? 520 : 52)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - 毛玻璃效果
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
