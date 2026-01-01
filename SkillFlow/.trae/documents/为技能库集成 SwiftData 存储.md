为了确保数据结构符合 `schema.json` 并能高效使用 SwiftData，我制定了以下计划：

1. **增强数据模型 (`Models.swift`)**

   * **定义 Codable 结构**：根据 `schema.json` 定义完整的 Swift 结构体（如 `AIPDLPackage`, `PackageMeta`, `AppSpec`, `Step` 等），确保能无损解析和生成符合 Schema 的 JSON。

   * **更新** **`Skill`** **模型**：

     * 添加 `packageData: Data?` 属性（使用 `@Attribute(.externalStorage)`），用于存储完整的符合 Schema 的 JSON 数据。

     * 保留 `name`, `software`, `createdAt` 等属性用于高效的列表查询和 UI 展示，并确保在保存时这些属性与 `packageData` 保持同步。

2. **重构视图模型 (`SkillLibraryViewModel.swift`)**

   * 移除模拟数据，改为处理业务逻辑（如导入/导出符合 Schema 的 JSON）。

   * 实现 `importSkill(from data: Data)`，将 JSON 解析为 `AIPDLPackage` 并转换为 `Skill` 对象存入 SwiftData。

   * 实现 `deleteSkill` 和筛选逻辑。

3. **更新侧边栏视图 (`SkillLibrarySidebar.swift`)**

   * 使用 `@Query` 直接从 SwiftData 获取 `Skill` 列表。

   * 对接 ViewModel 的逻辑。

4. **验证**

   * 编写一个符合 `schema.json` 的示例 JSON。

   * 通过“添加测试数据”功能，验证该 JSON 能被正确解析、存入 SwiftData，并在列表中正确显示。

