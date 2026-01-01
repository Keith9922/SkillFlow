根据您的要求，我已详细分析了现有的代码库（`domain/task.rs`, `service/task_service.rs`）和您提供的 PlantUML 时序图。

**确认结果**：
目前的后端逻辑核心 `MemTaskService` 已经实现了基础的任务状态管理（创建、更新音频/视频结果、完成、失败），逻辑闭环可用，符合时序图中的状态流转要求。

**接下来的实施计划**：

我将把 `MemTaskService` 接入 Web API 层，并实现异步任务处理的模拟逻辑（以验证轮询机制）。

### 1. 代码重构与 DTO 定义
- **重构 `handlers.rs`**：将其转换为模块结构，新增 `handlers/task.rs` 专门处理任务相关逻辑。
- **定义数据传输对象 (DTO)**：定义 `CreateTaskRequest`, `ParseAudioRequest` 等结构体，规范 API 输入输出。

### 2. 实现 API Handlers
按照时序图实现以下接口：
- `POST /v1/tasks/create`: 创建任务。
- `POST /v1/parse/audio`: 触发音频分析。
    - **实现细节**：将使用 `tokio::spawn` 模拟后台异步处理（延迟几秒后更新状态），以测试客户端的轮询逻辑。
- `POST /v1/parse/video`: 触发视频分析。
    - **实现细节**：同样使用异步模拟，依赖音频分析的结果。
- `GET /v1/tasks/status`: 查询任务状态。
- `GET /v1/tasks/artifact`: 获取特定轨道（audio/video/steps）的结果数据。
- `GET /v1/tasks/list`: 列出所有任务。

### 3. 应用状态管理 (AppState)
- 在 `main.rs` 中初始化 `MemTaskService` 并将其封装为 `AppState`。
- 确保 `handlers` 能够通过 `State` 访问共享的任务服务实例。

### 4. 路由配置
- 在 `router.rs` 中注册上述 `/v1` 路由，并与 `handlers` 绑定。

**注意**：
- 关于 Token 鉴权：目前的实现将暂时跳过具体的 Token 校验逻辑（或仅做简单的占位），优先保证业务流程跑通。
- 关于“不能采用模拟数据”：我会确保数据是在内存中真实流转和存储的，而不是直接返回写死的 JSON 响应。后台任务的延迟模拟是为了验证异步流程的真实性。

请确认是否开始执行此计划？