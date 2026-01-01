//
//  ErrorView.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import SwiftUI

struct ErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            // Error message
            VStack(spacing: 8) {
                Text("解析失败")
                    .font(.headline)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("关闭")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

#Preview {
    ErrorView(
        errorMessage: "网络连接失败，请检查网络设置后重试",
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}
