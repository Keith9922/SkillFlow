import SwiftUI

struct OperationStepsCard: View {
    let steps: [OperationStep]
    let currentStep: Int
    let onStartGuide: () -> Void
    let onAutomate: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片头部
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text("识别到 \(steps.count) 个操作步骤")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() }}) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.primary.opacity(0.03))
            
            if isExpanded {
                Divider().opacity(0.2)
                
                // 步骤列表
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        StepRow(
                            step: step,
                            index: index,
                            isActive: index == currentStep,
                            isCompleted: index < currentStep
                        )
                        
                        if index < steps.count - 1 {
                            StepConnector(isCompleted: index < currentStep)
                        }
                    }
                }
                .padding(14)
                
                Divider().opacity(0.2)
                
                // 操作按钮
                HStack(spacing: 10) {
                    Button(action: onStartGuide) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 12))
                            Text("引导教学")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onAutomate) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("自动执行")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct StepRow: View {
    let step: OperationStep
    let index: Int
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 步骤编号
            ZStack {
                Circle()
                    .fill(
                        isCompleted ? Color.green.opacity(0.15) :
                        isActive ? Color.blue.opacity(0.15) :
                        Color.primary.opacity(0.05)
                    )
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isActive ? .blue : .secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? .primary : .primary.opacity(0.7))
                
                Text(step.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.blue.opacity(0.05) : Color.clear)
        )
    }
}

struct StepConnector: View {
    let isCompleted: Bool
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(isCompleted ? Color.green.opacity(0.3) : Color.primary.opacity(0.1))
                .frame(width: 2, height: 16)
                .padding(.leading, 13)
            Spacer()
        }
    }
}
