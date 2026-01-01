//
//  InputBar.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct InputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onFileSelect: (URL) -> Void
    let isProcessing: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Skill.usageCount, order: .reverse) private var allSkills: [Skill]
    
    @State private var showingURLPicker = false
    @State private var showingFilePicker = false
    @State private var showSkillSuggestions = false
    @State private var filteredSkills: [Skill] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestions List
            if showSkillSuggestions && !filteredSkills.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSkills) { skill in
                            Button(action: {
                                selectSkill(skill)
                            }) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading) {
                                        Text(skill.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(skill.software)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.bottom, 8)
            }
            
            HStack(spacing: 8) {
                // File Upload Button
                Button(action: { showingFilePicker.toggle() }) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("上传本地视频")
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            onFileSelect(url)
                        }
                    case .failure(let error):
                        print("File selection error: \(error)")
                    }
                }
                
                // URL Button
                Button(action: { showingURLPicker.toggle() }) {
                    Image(systemName: "link")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("粘贴视频链接")
                
                // Text Input
                TextField("输入消息、粘贴链接或使用 @ 调用技能...", text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onChange(of: text) { _, newValue in
                        checkForSkillTrigger(newValue)
                    }
                    .onSubmit {
                        if !isProcessing {
                            // Close suggestions if open
                            showSkillSuggestions = false
                            onSend()
                        }
                    }
                
                // Send Button
                Button(action: onSend) {
                    Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(text.isEmpty && !isProcessing ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty && !isProcessing)
            }
            .padding(12)
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            )
            .sheet(isPresented: $showingURLPicker) {
                URLPickerView(text: $text, isPresented: $showingURLPicker)
            }
        }
    }
    
    private func checkForSkillTrigger(_ input: String) {
        // Simple logic: if last character is @ or we are typing after @
        if let atIndex = input.lastIndex(of: "@") {
            let suffix = input[atIndex...].dropFirst() // Text after @
            // If there's a space after @, likely not searching anymore or search term ended
            if suffix.contains(" ") {
                showSkillSuggestions = false
                return
            }
            
            let query = String(suffix)
            filterSkills(query: query)
            showSkillSuggestions = true
        } else {
            showSkillSuggestions = false
        }
    }
    
    private func filterSkills(query: String) {
        if query.isEmpty {
            filteredSkills = Array(allSkills.prefix(5))
        } else {
            filteredSkills = allSkills.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.software.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    private func selectSkill(_ skill: Skill) {
        if let atIndex = text.lastIndex(of: "@") {
            let prefix = text[..<atIndex]
            text = String(prefix) + "@" + skill.name + " "
        } else {
            // Fallback
            text += "@" + skill.name + " "
        }
        showSkillSuggestions = false
    }
}

struct URLPickerView: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    @State private var urlInput = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("粘贴视频链接")
                .font(.headline)
            
            TextField("https://...", text: $urlInput)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("确定") {
                    text = urlInput
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlInput.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 150)
    }
}
