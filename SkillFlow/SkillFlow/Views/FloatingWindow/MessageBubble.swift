//
//  MessageBubble.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
