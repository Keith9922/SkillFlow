//
//  SkillCard.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let onExecute: (ExecutionMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.headline)
                    
                    Text(skill.software)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
            
            // Description
            if !skill.skillDescription.isEmpty {
                Text(skill.skillDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Stats
            HStack(spacing: 16) {
                Label("\(skill.totalSteps) 步骤", systemImage: "list.bullet")
                Label("\(skill.estimatedDuration)s", systemImage: "clock")
                Label("\(skill.usageCount) 次", systemImage: "arrow.clockwise")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Tags
            if !skill.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(skill.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { onExecute(.guide) }) {
                    Label("引导模式", systemImage: "hand.point.up.left")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: { onExecute(.auto) }) {
                    Label("自动执行", systemImage: "play.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }
}
