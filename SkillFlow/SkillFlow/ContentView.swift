//
//  ContentView.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//  Note: This file is not used in the floating window version
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("SkillFlow")
                .font(.largeTitle)
            Text("请使用 ⌘ + Shift + Space 打开悬浮窗")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 300, height: 200)
    }
}

#Preview {
    ContentView()
}
