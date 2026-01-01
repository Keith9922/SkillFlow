//
//  FloatingWindowView.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI

struct FloatingWindowView: View {
    @State private var showSkillLibrary = false
    @State private var windowSize: CGSize = CGSize(width: 500, height: 600)
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Main Chat Area
            ChatView()
                .frame(width: windowSize.width, height: windowSize.height)
            
            // Skill Library Sidebar (slides from right)
            if showSkillLibrary {
                SkillLibrarySidebar(isShowing: $showSkillLibrary)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .overlay(alignment: .topTrailing) {
            // Skill Library Toggle Button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showSkillLibrary.toggle()
                }
            }) {
                Image(systemName: showSkillLibrary ? "sidebar.right" : "book.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(12)
            .help("技能库")
        }
    }
}
