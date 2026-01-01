//
//  SkillLibrarySidebar.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SkillLibrarySidebar: View {
    @StateObject private var viewModel = SkillLibraryViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Skill.createdAt, order: .reverse) private var allSkills: [Skill]
    @Binding var isShowing: Bool
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("技能库")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isShowing = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(VisualEffectBlur(material: .headerView, blendingMode: .behindWindow))
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索技能...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.categories, id: \.self) { category in
                        Button(action: {
                            viewModel.selectedCategory = category
                        }) {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.selectedCategory == category ?
                                    Color.blue : Color.gray.opacity(0.1)
                                )
                                .foregroundColor(
                                    viewModel.selectedCategory == category ?
                                    .white : .primary
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Skills List
            ScrollView {
                LazyVStack(spacing: 8) {
                    let displayedSkills = viewModel.filterSkills(allSkills)
                    
                    if displayedSkills.isEmpty {
                        Text(allSkills.isEmpty ? "暂无技能" : "无匹配技能")
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    } else {
                        ForEach(displayedSkills) { skill in
                            SkillListItem(skill: skill) {
                                // Insert skill reference into chat
                                NotificationCenter.default.post(
                                    name: .insertSkillReference,
                                    object: nil,
                                    userInfo: ["skill": skill]
                                )
                                isShowing = false
                            } onDelete: {
                                viewModel.deleteSkill(skill)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(allSkills.count) 个技能")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Menu {
                    Picker("排序", selection: $viewModel.sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Divider()
                    
                    Button("添加测试数据") {
                        viewModel.addSampleData()
                    }
                    
                    Divider()
                    
                    Button("导入技能 (JSON)...") {
                        isImporting = true
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
            .padding()
            .background(VisualEffectBlur(material: .headerView, blendingMode: .behindWindow))
        }
        .frame(width: 300)
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importSkill(from: url)
                }
            case .failure(let error):
                print("File import failed: \(error.localizedDescription)")
            }
        }
    }
}

struct SkillListItem: View {
    let skill: Skill
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(skill.software)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        // Try to get step count from packageData first, else fallback to steps count
                        let stepCount = skill.getPackage()?.steps.count ?? skill.totalSteps
                        Text("\(stepCount) 步骤")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Delete button (shown on hover)
                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let insertSkillReference = Notification.Name("insertSkillReference")
}
