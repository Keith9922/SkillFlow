//
//  APISettingsView.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import SwiftUI

struct APISettingsView: View {
    @StateObject private var config = APIConfiguration.shared
    @State private var showingResetAlert = false
    @State private var validationErrors: [String] = []
    
    var body: some View {
        Form {
            // API Version Selection
            Section {
                Picker("API 版本", selection: $config.currentVersion) {
                    ForEach(APIVersion.allCases, id: \.self) { version in
                        VStack(alignment: .leading) {
                            Text(version.displayName)
                            Text(version.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(version)
                    }
                }
                .pickerStyle(.radioGroup)
                
                if !validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("API 版本选择")
            } footer: {
                Text("选择要使用的 API 版本。切换版本后，应用将使用对应的后端服务。")
            }
            
            // SEEDO API Configuration
            if config.currentVersion == .seedo {
                Section {
                    TextField("Base URL", text: $config.seedoBaseURL)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("S3 Bucket", text: $config.s3Bucket)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("S3 Region", text: $config.s3Region)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("SEEDO API 配置")
                } footer: {
                    Text("配置 SEEDO API 的服务器地址和 S3 存储信息。")
                }
            }
            
            // Legacy API Configuration
            if config.currentVersion == .legacy {
                Section {
                    TextField("Base URL", text: $config.legacyBaseURL)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("旧版 API 配置")
                } footer: {
                    Text("配置旧版 WebSocket API 的服务器地址。")
                }
            }
            
            // Actions
            Section {
                HStack {
                    Button("验证配置") {
                        validateConfiguration()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("重置为默认") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 400)
        .alert("重置配置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                config.resetToDefaults()
                validationErrors = []
            }
        } message: {
            Text("确定要将所有配置重置为默认值吗？")
        }
    }
    
    private func validateConfiguration() {
        validationErrors = config.validateConfiguration()
        
        if validationErrors.isEmpty {
            // Show success feedback
            NSSound.beep()
        }
    }
}

#Preview {
    APISettingsView()
}
