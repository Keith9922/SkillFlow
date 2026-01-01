# VLM 驱动的 macOS 自动化实现计划

本计划旨在实现基于视觉大模型（VLM）和 Apple Vision 框架的 macOS 自动化操作流程。通过截图、视觉分析、模型决策和模拟输入，实现对屏幕的智能控制。

## 1. 基础服务层建设 (Foundation Services)

### 1.1 ScreenCaptureService (屏幕捕获)

* **目标**: 获取当前主屏幕的高清截图。

* **实现**: 使用 `CoreGraphics` 的 `CGDisplayCreateImage(CGMainDisplayID())`。

* **输出**: `NSImage` 或 `Data` (JPEG/PNG)，支持调整压缩质量以适应 VLM Token 限制。

### 1.2 VisionAnalysisService (视觉分析)

* **目标**: 提取屏幕上的文字信息及其位置，辅助 VLM 定位。

* **实现**: 使用 `Vision` 框架的 `VNRecognizeTextRequest`。

* **输出**: 自定义结构体 `OCRResult` 数组，包含 `text` 和 `normalizedRect` (归一化坐标)。

* **坐标处理**: 保持 Vision 的原始坐标（左下原点），在 Prompt 中说明或在服务层统一转换为左上原点。

### 1.3 AutomationService (自动化执行)

* **目标**: 执行具体的鼠标和键盘操作。

* **实现**: 使用 `Quartz Event Services (CGEvent)`。

* **功能**:

  * `click(x: Double, y: Double)`: 单击指定归一化坐标（需转换为屏幕像素）。

  * `type(text: String)`: 模拟键盘输入。

  * `scroll(dx: Int, dy: Int)`: 模拟滚轮。

  * `mouseMove(x: Double, y: Double)`: 移动鼠标。

* **坐标转换**: 实现 `normalizedToScreen(x, y)` 方法，处理 Y 轴翻转（Vision 左下 -> 屏幕左上）。

## 2. API 扩展 (API Service Extension)

### 2.1 扩展 APIService

* **目标**: 支持通用的 SiliconFlow VLM 调用。

* **方法**: `func generateAction(image: Data, ocrContext: String, goal: String, history: String) async throws -> VLMAction`。

* **模型**: 使用 `Qwen/Qwen2.5-VL-72B-Instruct`。

* **Prompt 构建**:

  * System: 定义角色为 macOS 自动化助手，输出严格的 JSON 格式。

  * User: 包含截图 (Base64)、OCR 上下文 (JSON 字符串)、用户目标、历史操作摘要。

## 3. 核心逻辑层 (Core Logic)

### 3.1 定义 VLMAction 模型

* **结构**:

  ```swift
  struct VLMAction: Codable {
      let thought: String // 思考过程
      let action: String  // click, type, scroll, done, fail
      let x: Double?      // 0-1
      let y: Double?      // 0-1
      let text: String?   // 输入内容
  }
  ```

### 3.2 实现 VLMAutomationManager (或集成进 ExecutionViewModel)

* **流程**:

  1. **Capture**: 调用 `ScreenCaptureService` 截图。
  2. **Analyze**: 调用 `VisionAnalysisService` 获取 OCR 数据。
  3. **Think**: 构造 Prompt，调用 `APIService` 获取 `VLMAction`。
  4. **Act**: 解析 Action，调用 `AutomationService` 执行。
  5. **Loop**: 根据 Action 类型决定是否继续（如 `done` 则停止，否则等待后继续）。

## 4. UI 集成与测试 (UI Integration)

### 4.1 更新 ChatViewModel / ExecutionViewModel

* 添加触发 VLM 自动化的入口（例如在输入框输入特定指令或点击按钮）。

* 显示当前的“思考”状态和“操作”意图（利用 `highlightRect` 在屏幕上绘制预告）。

### 4.2 权限处理

* 确保 App 拥有 Screen Recording 和 Accessibility 权限。

* 添加权限检查逻辑，未授权时提示用户。

## 5. 开发步骤

1. **创建数据模型**: 定义 `VLMAction` 和 `OCRResult`。
2. **实现 ScreenCaptureService**: 封装截图逻辑。
3. **实现 VisionAnalysisService**: 封装 OCR 逻辑。
4. **实现 AutomationService**: 封装 CGEvent 逻辑。
5. **更新 APIService**: 添加 VLM 调用接口。
6. **编写编排逻辑**: 在 ViewModel 中串联上述服务。
7. **测试验证**: 使用简单的任务（如“点击 Safari 图标”）验证闭环。

