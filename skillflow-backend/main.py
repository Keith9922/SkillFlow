"""
SkillFlow Backend - FastAPI Server
视频解析 AI 服务
"""
import os
from fastapi import FastAPI, UploadFile, File, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
import uvicorn

from api.routes import router
from api.websocket import ConnectionManager

# 加载环境变量
load_dotenv()

# 创建 FastAPI 应用
app = FastAPI(
    title="SkillFlow AI Service",
    description="视频教程解析服务",
    version="1.0.0"
)

# CORS 配置（允许前端访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(router, prefix="/api")

# WebSocket 连接管理器
manager = ConnectionManager()

@app.get("/")
async def root():
    """健康检查"""
    return {
        "status": "ok",
        "service": "SkillFlow AI Service",
        "version": "1.0.0"
    }

@app.get("/api/health")
async def health_check():
    """健康检查接口"""
    return {
        "status": "healthy",
        "qwen_api": "configured" if os.getenv("QWEN_API_KEY") else "missing",
        "deepseek_api": "configured" if os.getenv("DEEPSEEK_API_KEY") else "missing"
    }

@app.websocket("/ws/progress/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """WebSocket 进度推送"""
    await manager.connect(websocket, client_id)
    try:
        while True:
            # 保持连接
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(client_id)

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info"
    )
