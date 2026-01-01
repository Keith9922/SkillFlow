import SwiftUI

// MARK: - 引导遮罩视图（用于新手引导教学）
struct GuidedOverlayView: View {
    let step: OperationStep
    let targetFrame: CGRect
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @State private var bubbleOffset: CGFloat = 20
    
    var body: some View {
        ZStack {
            // 全屏遮罩
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // 高亮区域（镂空）
            Rectangle()
                .fill(Color.clear)
                .frame(width: targetFrame.width + 16, height: targetFrame.height + 16)
                .position(x: targetFrame.midX, y: targetFrame.midY)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.blue, lineWidth: 3)
                        .shadow(color: .blue.opacity(0.5), radius: 10)
                )
                .blendMode(.destinationOut)
            
            // 提示气泡
            GuideBubble(step: step, onNext: onNext, onSkip: onSkip)
                .position(
                    x: targetFrame.midX,
                    y: targetFrame.maxY + 80
                )
                .offset(y: bubbleOffset)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) {
                        bubbleOffset = 0
                    }
                }
        }
        .compositingGroup()
    }
}

struct GuideBubble: View {
    let step: OperationStep
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 箭头指示
            Triangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: 20, height: 10)
                .rotationEffect(.degrees(180))
                .offset(x: -60)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(step.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 10) {
                    Button("跳过", action: onSkip)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: onNext) {
                        HStack(spacing: 4) {
                            Text("下一步")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            )
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
