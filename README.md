# SkillFlow - 让收藏夹里的教程变成你的技能库

> 刷到即学会，见过就掌握

SkillFlow 是一个 macOS 应用，可以将视频教程自动解析为可执行的操作技能，支持引导式学习和自动化执行。

## ✨ 核心功能

- 🎥 **视频解析** - 支持 B站、YouTube、抖音等平台
- 🤖 **AI 分析** - 使用 Qwen2.5-VL 和 DeepSeek-OCR 识别操作
- 📚 **技能库** - 保存和管理你的技能
- 🎯 **引导模式** - 逐步指导你完成操作
- ⚡ **自动模式** - 全自动执行技能
- 💬 **对话交互** - ChatGPT 风格的对话界面
- ⌨️ **全局快捷键** - ⌘ + Shift + Space 快速唤起

## 🚀 快速开始

### 1. 启动后端

```bash
cd skillflow-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

后端将在 `http://localhost:8000` 启动

### 2. 运行前端

```bash
open SkillFlow/SkillFlow.xcodeproj
```

在 Xcode 中按 `⌘ + R` 运行应用

### 3. 授予权限

首次运行需要授予：
- 辅助功能权限
- 屏幕录制权限

### 4. 开始使用

1. 按 `⌘ + Shift + Space` 唤起悬浮窗
2. 粘贴视频链接
3. 等待解析完成
4. 选择执行模式（引导/自动）
5. 技能自动保存到技能库

## 📖 文档

- [快速启动指南](快速启动指南.md) - 详细的环境配置
- [测试指南](测试指南.md) - 完整的测试流程
- [项目完成总结](项目完成总结.md) - 项目概览
- [完整开发方案](完整开发方案-前后端.md) - 技术细节
- [PRD 文档](PRD文档.md) - 产品需求

## 🏗️ 技术栈

### 后端
- Python 3.8+
- FastAPI
- OpenCV
- yt-dlp
- WebSocket

### 前端
- Swift 5.0+
- SwiftUI
- SwiftData
- Accessibility API
- Carbon API

## 📁 项目结构

```
.
├── skillflow-backend/          # Python 后端
│   ├── api/                    # API 路由
│   ├── services/               # 核心服务
│   ├── tests/                  # 单元测试
│   └── main.py                 # 入口文件
│
├── SkillFlow/                  # Swift 前端
│   └── SkillFlow/
│       ├── Services/           # 服务层
│       ├── ViewModels/         # 视图模型
│       ├── Views/              # UI 组件
│       └── SkillFlowApp.swift  # 应用入口
│
└── docs/                       # 文档
    ├── PRD文档.md
    ├── 技术实现方案.md
    └── ...
```

## 🎯 使用场景

### 场景 1: 图像处理新手
小明需要给证件照换底色，但不会用 Photoshop。
1. 找到 B站 PS 换底教程
2. 粘贴链接到 SkillFlow
3. 选择"引导模式"
4. 跟着高亮提示完成操作
5. 技能保存，下次直接用

### 场景 2: 重复性工作
王大明每周需要整理 Excel 数据报表。
1. 录制一次操作流程
2. 保存为技能
3. 下次直接 `@整理报表`
4. 选择"自动模式"
5. 喝杯咖啡，工作完成

### 场景 3: 系统学习
张伟想学习 Figma 设计。
1. 导入 40 小时系统教程
2. AI 自动拆解为 128 个技能点
3. 按需学习每个技能
4. 边学边练，快速掌握

## 🔧 配置

### 后端配置

编辑 `skillflow-backend/.env`:

```env
# AI API Keys (可选，Mock 模式不需要)
QWEN_API_KEY=your_qwen_api_key
DEEPSEEK_API_KEY=your_deepseek_api_key

# 服务器配置
HOST=0.0.0.0
PORT=8000
```

### 前端配置

在 `SkillFlow/SkillFlow/Info.plist` 中已配置权限描述。

## 🧪 测试

### 后端测试

```bash
cd skillflow-backend
pytest tests/ -v
```

### 前端测试

在 Xcode 中按 `⌘ + U` 运行测试

### 集成测试

参考 [测试指南](测试指南.md)

## 📊 开发进度

- ✅ 后端 API 服务 (100%)
- ✅ 视频解析 (100%)
- ✅ AI 分析 (100%)
- ✅ 前端 UI (100%)
- ✅ 技能执行 (100%)
- ⏳ 测试与优化 (0%)

**总体进度: 70%**

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

## 📄 许可

Copyright © 2026 SkillFlow. All rights reserved.

## 🔗 相关链接

- [IntuitionX 黑客松](https://intuitionx.com)
- [Qwen2.5-VL](https://github.com/QwenLM/Qwen2.5-VL)
- [DeepSeek](https://www.deepseek.com)

## 💡 Slogan

**刷到即学会，见过就掌握**  
让每个教程视频都变成你的肌肉记忆

---

Made with ❤️ for IntuitionX Hackathon
