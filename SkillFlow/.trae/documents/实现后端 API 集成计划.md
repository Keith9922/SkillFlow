# 实现后端 API 集成

我将实现 `APIService` 并集成 `/v1/tasks/create` 和 `/v1/parse/*` 系列接口，完成从 S3 上传后到最终结果生成的完整链路。实现过程中可以多参考 API MCP 确认 API 请求详细信息，尽量一遍做对。

## 1. 创建 `APIService.swift`

负责处理所有与业务后端的 HTTP 通信。

### 数据模型 (Models)

定义请求和响应的 Codable 结构体：

* `CreateTaskResponse`: 包含 `entryId`。

* `AudioParseRequest`: 包含 `entryId`, `audioUrl`。

* `VideoParseRequest`: 包含 `entryId`, `videoUrl`, `transcriptText`。

* `StepsParseRequest`: 包含 `entryId`。

* `TaskStatusResponse`: 用于解析 `/v1/tasks/status` 的响应（由于文档未定义具体字段，将使用通用结构或 `[String: Any]` 调试）。

### API 方法

* `createTask() -> String`: 调用 `/v1/tasks/create`。

* `parseAudio(entryId, url)`: 调用 `/v1/parse/audio`。

* `parseVideo(entryId, url, text)`: 调用 `/v1/parse/video`。

* `generateSteps(entryId)`: 调用 `/v1/parse/steps`。

* `checkStatus(entryId) -> TaskStatusResponse`: 调用 `/v1/tasks/status`。

## 2. 更新 `ChatViewModel.swift`

重构业务流程，引入状态机和轮询机制。

### 流程重构

1. **S3 上传完成**: 获取 `videoUrl`, `audioUrl`。
2. **创建任务**: 调用 `createTask`，获取 `entryId`。
3. **音频阶段**:

   * 调用 `parseAudio`。

   * **轮询** `checkStatus`，直到音频解析完成，提取 `transcriptText`。
4. **视频阶段**:

   * 调用 `parseVideo` (使用上一步的 `transcriptText`)。

   * **轮询** `checkStatus`，直到视频分析完成。
5. **步骤生成阶段**:

   * 调用 `generateSteps`。

   * **轮询** `checkStatus`，直到最终完成。
6. **完成**: 展示最终结果。

## 3. 轮询机制

* 在 ViewModel 中实现 `pollTaskStatus(entryId, targetStage)` 方法。

* 设置合理的轮询间隔（如 2 秒）。

* 处理超时和错误情况。

## 4. 验证

* 通过日志打印 `/v1/tasks/status` 的原始响应，以确认未知的字段结构。

* 确保 UI 进度条随真实后端状态更新。

