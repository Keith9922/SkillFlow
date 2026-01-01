# 删除逻辑代码并保留 UI/布局的实施计划

根据你的要求，我将删除项目中所有的逻辑实现代码，仅保留 UI 设计和布局代码，并清理 ViewModel 使其仅作为 UI 状态的容器。

## 1. 需要实现逻辑的交互入口点汇总
在执行删除之前，以下是目前识别到的所有需要后续重新实现逻辑的交互点：

### **TaskList (任务列表)**
- **刷新按钮** (`arrow.clockwise`): 点击刷新任务列表。
- **下拉刷新**: 列表下拉触发加载。
- **列表项点击**: 进入任务详情。
- **错误弹窗确定**: 清除错误状态。

### **SkillLibrary (技能库)**
- **搜索框**: 输入文本实时搜索技能。
- **清除搜索**: 清除搜索关键词。
- **分类筛选**: 切换技能分类。
- **排序选择**: 改变技能排序方式。
- **选择技能**: 将技能插入聊天或选中。
- **删除技能**: 鼠标悬停时显示的删除操作。
- **关闭侧边栏**: 隐藏技能库。

### **FloatingWindow (悬浮窗/聊天)**
- **文件上传**: 选择本地视频文件。
- **URL 输入**: 弹出 URL 输入框。
- **发送按钮**: 发送消息或停止处理。
- **输入框提交**: 回车发送消息。
- **URL 弹窗确认/取消**: 处理 URL 输入。
- **技能卡片操作**: 点击“引导模式”或“自动执行”。
- **切换技能库**: 展开/收起侧边栏。

### **GuideMode (引导模式)**
- **流程控制**: 暂停、继续、下一步、停止按钮。

### **Settings (设置)**
- **API 配置验证**: 验证服务器连接。
- **重置配置**: 恢复默认设置。
- **保存配置**: (通常在输入框变更或退出时保存)。

---

## 2. 实施步骤

### 第一步：删除核心逻辑层
将直接删除 `Services` 目录下的所有业务逻辑实现文件：
- `APIConfiguration.swift`, `APIServiceFactory.swift`
- `ExecutionEngine.swift`, `PollingManager.swift`
- `S3Uploader.swift`, `VideoDownloader.swift`
- `SEEDOAPIService.swift`, `TokenManager.swift`
- `HotKeyManager.swift` 等所有服务类文件。

### 第二步：清理 ViewModels
重构所有 ViewModel，移除对 Service 的依赖，仅保留 `@Published` 属性用于 UI 预览，并将所有方法替换为为空实现（或仅打印日志）：
- **`ChatViewModel`**: 移除上传、解析、轮询逻辑。
- **`TaskListViewModel`**: 移除 API 调用。
- **`SkillLibraryViewModel`**: 移除数据库查询和筛选逻辑。
- **`ExecutionViewModel`**: 移除自动化执行逻辑。

### 第三步：清理 App 入口
- 修改 `SkillFlowApp.swift` 和 `AppDelegate`，移除 `HotKeyManager` 的注册和初始化代码，确保应用能正常启动显示 UI。

### 第四步：验证
- 确认所有 Views 无编译错误（因移除了 Services，ViewModel 的修改将修复这些引用错误）。
- 确保 UI 结构保持完整，所有按钮可见但点击无实际业务响应。

请确认是否开始执行此计划？