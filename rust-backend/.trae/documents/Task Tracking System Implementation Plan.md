# 实现任务追踪系统 (Task Tracking System)

基于 PlantUML 时序图和现有项目结构，我制定了以下实现计划。我们将优先实现核心业务逻辑和状态流转，确保其正确性，然后再考虑 API 层的暴露。

## 1. 领域模型设计 (`src/domain/task.rs`)
我们将定义核心数据结构来表达任务及其状态。

*   **`TaskStatus` Enum**:
    *   `Processing`: 任务创建后的初始状态，以及各阶段进行中。
    *   `AudioDone`: 音频解析完成。
    *   `VideoDone`: 视频分析完成。
    *   `Finished`: 步骤生成完成（最终态）。
    *   `Failed`: 任何阶段发生错误。
*   **`Task` Struct**:
    *   `entry_id`: String (唯一标识)
    *   `dir_location`: String (S3 路径)
    *   `transcript_text`: Option<String> (ASR 结果)
    *   `video_analysis`: Option<serde_json::Value> (视频分析结果)
    *   `steps_package`: Option<serde_json::Value> (最终步骤结果)
    *   `status`: TaskStatus
    *   `error`: Option<String>
    *   `created_at`: DateTime
    *   `updated_at`: DateTime

## 2. 业务逻辑实现 (`src/service/task_service.rs`)
我们将实现一个内存版本的任务服务 (`MemTaskService`) 来管理状态流转。后续可轻松替换为数据库实现。

*   **接口定义**:
    *   `create_task(dir_location)`: 创建新任务，生成 `entryId`。
    *   `update_audio_result(entry_id, transcript)`: 更新音频结果，状态变更为 `AudioDone`。
    *   `update_video_result(entry_id, analysis)`: 更新视频结果，状态变更为 `VideoDone`。
    *   `update_steps_result(entry_id, steps)`: 更新步骤结果，状态变更为 `Finished`。
    *   `mark_as_failed(entry_id, error)`: 标记任务失败。
    *   `get_task(entry_id)`: 获取任务详情。
    *   `list_tasks()`: 列出所有任务。

## 3. 验证计划 (Unit Tests)
在 `src/service/task_service.rs` 中编写单元测试，模拟完整的业务流程：
1.  **Happy Path**: Create -> Update Audio -> Update Video -> Update Steps -> Check Finished.
2.  **Error Path**: Create -> Fail -> Check Failed.
3.  **Data Integrity**: 验证每个阶段的数据（如 transcript）是否正确保存。

## 文件变更清单
1.  创建 `src/domain/mod.rs` 和 `src/domain/task.rs`。
2.  创建 `src/service/mod.rs` 和 `src/service/task_service.rs`。
3.  修改 `src/main.rs` 引入新模块。

确认后，我将开始编码并执行验证。