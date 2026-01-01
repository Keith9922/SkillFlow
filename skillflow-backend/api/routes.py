"""
API 路由
"""
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel, HttpUrl
from typing import Optional
import asyncio

from services.video_processor import VideoProcessor
from services.ai_analyzer import AIAnalyzer
from services.step_generator import StepGenerator
from api.websocket import ConnectionManager

router = APIRouter()
manager = ConnectionManager()

class VideoAnalysisRequest(BaseModel):
    """视频分析请求"""
    video_url: str
    client_id: str
    target_software: Optional[str] = None

class VideoAnalysisResponse(BaseModel):
    """视频分析响应"""
    task_id: str
    status: str
    message: str

@router.post("/analyze-video", response_model=VideoAnalysisResponse)
async def analyze_video(
    request: VideoAnalysisRequest,
    background_tasks: BackgroundTasks
):
    """
    视频解析接口
    
    接收视频链接，后台异步解析，通过 WebSocket 推送进度
    """
    try:
        # 生成任务 ID
        import uuid
        task_id = str(uuid.uuid4())
        
        # 添加后台任务
        background_tasks.add_task(
            process_video_task,
            task_id=task_id,
            video_url=request.video_url,
            client_id=request.client_id,
            target_software=request.target_software
        )
        
        return VideoAnalysisResponse(
            task_id=task_id,
            status="processing",
            message="视频解析已开始，请通过 WebSocket 接收进度"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def process_video_task(
    task_id: str,
    video_url: str,
    client_id: str,
    target_software: Optional[str]
):
    """
    后台视频处理任务
    """
    try:
        # 1. 下载视频
        await manager.send_progress(client_id, {
            "stage": "downloading",
            "progress": 0,
            "message": "正在下载视频..."
        })
        
        processor = VideoProcessor()
        video_path = await processor.download_video(video_url)
        
        # 2. 抽帧处理
        await manager.send_progress(client_id, {
            "stage": "extracting",
            "progress": 20,
            "message": "正在提取关键帧..."
        })
        
        frames = await processor.extract_key_frames(video_path)
        audio_path = await processor.extract_audio(video_path)
        
        # 3. AI 分析
        await manager.send_progress(client_id, {
            "stage": "analyzing",
            "progress": 40,
            "message": f"正在分析 {len(frames)} 个关键帧..."
        })
        
        analyzer = AIAnalyzer()
        analysis_results = await analyzer.analyze_frames(
            frames=frames,
            audio_path=audio_path,
            progress_callback=lambda p: asyncio.create_task(
                manager.send_progress(client_id, {
                    "stage": "analyzing",
                    "progress": 40 + int(p * 0.4),
                    "message": f"AI 分析中... {int(p * 100)}%"
                })
            )
        )
        
        # 4. 生成步骤
        await manager.send_progress(client_id, {
            "stage": "generating",
            "progress": 80,
            "message": "正在生成操作步骤..."
        })
        
        generator = StepGenerator()
        skill_data = await generator.generate_skill(
            analysis_results=analysis_results,
            target_software=target_software
        )
        
        # 5. 完成
        await manager.send_progress(client_id, {
            "stage": "completed",
            "progress": 100,
            "message": "解析完成！",
            "data": skill_data
        })
        
        # 清理临时文件
        processor.cleanup(video_path, audio_path)
        
    except Exception as e:
        await manager.send_progress(client_id, {
            "stage": "error",
            "progress": 0,
            "message": f"解析失败: {str(e)}"
        })

@router.get("/test")
async def test_endpoint():
    """测试接口"""
    return {"message": "API is working!"}
