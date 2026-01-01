//
//  InputBar.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import UniformTypeIdentifiers

struct InputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onFileSelect: (URL) -> Void
    let isProcessing: Bool
    
    @State private var showingURLPicker = false
    @State private var showingFilePicker = false
    
    var body: some View {
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
            TextField("输入消息、粘贴链接或拖拽视频文件...", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onSubmit {
                    if !isProcessing {
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
