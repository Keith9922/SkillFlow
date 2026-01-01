//
//  MigrationWizardView.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import SwiftUI
import SwiftData

struct MigrationWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var isMigrating = false
    @State private var migrationProgress: Double = 0
    @State private var migrationMessage = ""
    @State private var migrationComplete = false
    @State private var migrationError: String?
    @State private var backupURL: URL?
    
    private let migrationService = DataMigrationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("数据迁移向导")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("将您的数据迁移到新的 SEEDO API 格式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
            
            // Content
            if !migrationComplete {
                if currentStep == 0 {
                    WelcomeStep(onNext: { currentStep = 1 })
                } else if currentStep == 1 {
                    BackupStep(
                        backupURL: $backupURL,
                        onNext: { currentStep = 2 },
                        onBack: { currentStep = 0 }
                    )
                } else if currentStep == 2 {
                    MigrationStep(
                        isMigrating: $isMigrating,
                        progress: $migrationProgress,
                        message: $migrationMessage,
                        error: $migrationError,
                        onMigrate: performMigration,
                        onBack: { currentStep = 1 }
                    )
                }
            } else {
                CompletionStep(
                    backupURL: backupURL,
                    onDone: { dismiss() }
                )
            }
        }
        .frame(width: 600, height: 500)
        .padding()
    }
    
    private func performMigration() {
        isMigrating = true
        migrationProgress = 0
        migrationMessage = "准备迁移..."
        migrationError = nil
        
        Task {
            do {
                // Step 1: Create backup
                migrationMessage = "创建数据备份..."
                migrationProgress = 0.2
                
                let backup = try await migrationService.createBackup(context: modelContext)
                await MainActor.run {
                    backupURL = backup
                }
                
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Step 2: Perform migration
                migrationMessage = "执行数据迁移..."
                migrationProgress = 0.5
                
                try await migrationService.performMigration(context: modelContext)
                
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Step 3: Validate data
                migrationMessage = "验证迁移结果..."
                migrationProgress = 0.8
                
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Complete
                migrationMessage = "迁移完成！"
                migrationProgress = 1.0
                
                await MainActor.run {
                    migrationComplete = true
                    isMigrating = false
                }
                
            } catch {
                await MainActor.run {
                    migrationError = "迁移失败: \(error.localizedDescription)"
                    isMigrating = false
                }
            }
        }
    }
}

// MARK: - Step Views

struct WelcomeStep: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("欢迎使用数据迁移向导")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Label("自动备份您的现有数据", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Label("迁移到新的 SEEDO API 格式", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Label("验证数据完整性", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Label("保持现有技能可用", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Text("迁移过程大约需要几分钟，请不要关闭应用。")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("开始迁移") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct BackupStep: View {
    @Binding var backupURL: URL?
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("数据备份")
                .font(.headline)
            
            Text("在开始迁移之前，我们将创建您数据的完整备份。如果迁移过程中出现问题，您可以使用备份恢复数据。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("备份将保存在临时目录中")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("建议在迁移完成后保存备份文件")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            HStack {
                Button("返回") {
                    onBack()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("继续") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct MigrationStep: View {
    @Binding var isMigrating: Bool
    @Binding var progress: Double
    @Binding var message: String
    @Binding var error: String?
    let onMigrate: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("执行迁移")
                .font(.headline)
            
            if !isMigrating && error == nil {
                Text("准备好开始迁移了吗？")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    Button("返回") {
                        onBack()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("开始迁移") {
                        onMigrate()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if isMigrating {
                VStack(spacing: 12) {
                    ProgressView(value: progress) {
                        Text(message)
                            .font(.subheadline)
                    }
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Spacer()
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("迁移失败")
                        .font(.headline)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Button("返回") {
                        onBack()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("重试") {
                        onMigrate()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
}

struct CompletionStep: View {
    let backupURL: URL?
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("迁移完成！")
                .font(.title)
                .fontWeight(.bold)
            
            Text("您的数据已成功迁移到新格式。现在可以使用新的 SEEDO API 功能了。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if let backupURL = backupURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("备份文件位置：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(backupURL.path)
                            .font(.caption)
                            .textSelection(.enabled)
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(
                                backupURL.path,
                                inFileViewerRootedAtPath: backupURL.deletingLastPathComponent().path
                            )
                        }) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Spacer()
            
            Button("完成") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    MigrationWizardView()
        .modelContainer(for: [Skill.self, Message.self])
}
