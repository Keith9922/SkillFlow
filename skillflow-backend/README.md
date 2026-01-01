# SkillFlow Backend - AI 视频解析服务

## 快速开始

### 1. 安装依赖

```bash
# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # macOS/Linux

# 安装依赖
pip install -r requirements.txt
```

### 2. 配置环境变量

```bash
# 复制配置文件
cp .env.example .env

# 编辑 .env 文件，填入 API Key
# QWEN_API_KEY=your_key_here
# DEEPSEEK_API_KEY=your_key_here
```

### 3. 启动服务

```bash
python main.py
```

服务将在 `http://localhost:8000` 启动

### 4. 测试 API

```bash
# 健康检查
curl http://localhost:8000/api/health

# 测试接口
curl http://localhost:8000/api/test
```

## API 文档

### POST /api/analyze-video

视频解析接口

**请求体**:
```json
{
  "video_url": "https://www.bilibili.com/video/BV1xx...",
  "client_id": "unique_client_id",
  "target_software": "Photoshop"
}
```

**响应**:
```json
{
  "task_id": "uuid",
  "status": "processing",
  "message": "视频解析已开始"
}
```

### WebSocket /ws/progress/{client_id}

实时进度推送

**消息格式**:
```json
{
  "stage": "analyzing",
  "progress": 50,
  "message": "AI 分析中...",
  "data": null
}
```

## 项目结构

```
skillflow-backend/
├── main.py                    # FastAPI 入口
├── api/
│   ├── routes.py             # API 路由
│   └── websocket.py          # WebSocket 管理
├── services/
│   ├── video_processor.py    # 视频处理
│   ├── ai_analyzer.py        # AI 分析
│   └── step_generator.py     # 步骤生成
├── requirements.txt
└── README.md
```

## 开发说明

### Mock 模式

如果未配置 API Key，系统会自动使用 Mock 数据进行测试。

### 日志

日志输出到控制台，包含：
- 视频下载进度
- 帧提取信息
- AI 分析结果
- 错误信息

## 注意事项

1. 视频文件会临时保存在 `./temp` 目录
2. 处理完成后会自动清理临时文件
3. 建议视频大小不超过 500MB
4. API 调用会产生费用，请注意控制
