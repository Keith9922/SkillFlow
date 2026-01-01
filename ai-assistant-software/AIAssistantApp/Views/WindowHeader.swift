import SwiftUI

struct WindowHeader: View {
    @Binding var isExpanded: Bool
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.cyan.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text("AI Assistant")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary.opacity(0.9))
            
            Spacer()
            
            // 状态指示器
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.5), radius: 4)
                
                Text("在线")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // 折叠按钮
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(isHovering ? 0.1 : 0))
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.primary.opacity(0.02))
    }
}
