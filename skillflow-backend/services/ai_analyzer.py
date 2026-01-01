"""
AI 分析服务
使用 Qwen2.5-VL 和 DeepSeek-OCR 分析视频帧
"""
import os
import base64
import cv2
import numpy as np
from typing import List, Tuple, Dict, Callable, Optional
from openai import OpenAI
import asyncio

class AIAnalyzer:
    """AI 分析器"""
    
    def __init__(self):
        self.qwen_api_key = os.getenv("QWEN_API_KEY")
        self.deepseek_api_key = os.getenv("DEEPSEEK_API_KEY")
        
        # 初始化 OpenAI 客户端（用于 Qwen API）
        if self.qwen_api_key:
            self.client = OpenAI(
                api_key=self.qwen_api_key,
                base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"
            )
        else:
            print("警告: QWEN_API_KEY 未配置，将使用 Mock 数据")
            self.client = None
    
    async def analyze_frames(
        self,
        frames: List[Tuple[float, np.ndarray]],
        audio_path: Optional[str] = None,
        progress_callback: Optional[Callable] = None
    ) -> List[Dict]:
        """
        分析所有帧
        
        Args:
            frames: [(timestamp, frame_image)]
            audio_path: 音频文件路径
            progress_callback: 进度回调函数
        
        Returns:
            List[分析结果]
        """
        results = []
        total = len(frames)
        
        # TODO: 实现音频转文字（Whisper）
        audio_transcript = await self._transcribe_audio(audio_path) if audio_path else {}
        
        for idx, (timestamp, frame) in enumerate(frames):
            # 获取对应时间的语音文字
            audio_text = self._get_audio_at_time(audio_transcript, timestamp)
            
            # 分析单帧
            analysis = await self._analyze_single_frame(
                frame=frame,
                timestamp=timestamp,
                audio_text=audio_text
            )
            
            results.append(analysis)
            
            # 更新进度
            if progress_callback:
                await progress_callback((idx + 1) / total)
        
        return results
    
    async def _analyze_single_frame(
        self,
        frame: np.ndarray,
        timestamp: float,
        audio_text: str = ""
    ) -> Dict:
        """
        分析单个帧
        """
        if not self.client:
            # Mock 数据（用于测试）
            return self._generate_mock_analysis(timestamp, audio_text)
        
        try:
            # 将图片转为 base64
            _, buffer = cv2.imencode('.jpg', frame)
            image_base64 = base64.b64encode(buffer).decode('utf-8')
            
            # 构建 Prompt
            prompt = self._build_analysis_prompt(timestamp, audio_text)
            
            # 调用 Qwen2.5-VL API
            response = self.client.chat.completions.create(
                model="qwen-vl-plus",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{image_base64}"
                                }
                            }
                        ]
                    }
                ],
                temperature=0.1,
                max_tokens=1000
            )
            
            # 解析响应
            content = response.choices[0].message.content
            
            # 尝试解析 JSON
            import json
            try:
                analysis = json.loads(content)
            except:
                # 如果不是 JSON，包装成结构化数据
                analysis = {
                    "timestamp": timestamp,
                    "raw_response": content,
                    "software": "Unknown",
                    "action_type": "unknown"
                }
            
            analysis["timestamp"] = timestamp
            analysis["audio_text"] = audio_text
            
            return analysis
            
        except Exception as e:
            print(f"分析帧失败 (t={timestamp}): {e}")
            return self._generate_mock_analysis(timestamp, audio_text)
    
    def _build_analysis_prompt(self, timestamp: float, audio_text: str) -> str:
        """构建分析 Prompt"""
        return f"""
你是一名软件操作专家。请分析这个截图：

时间: {timestamp:.1f}秒
讲解内容: {audio_text}

请识别：
1. 使用的软件名称（如 Photoshop, Excel, Chrome 等）
2. 当前操作的UI元素（按钮/菜单/工具/输入框）
3. 操作类型（click/input/drag/shortcut/menu）
4. 元素的定位信息：
   - 位置描述（如"左侧工具栏第3个"、"顶部菜单栏"）
   - 图标描述（如"魔术棒形状"、"红色圆形按钮"）
   - 文字标签（如果有可见文字）
   - 区域（left_toolbar/top_menu/center_canvas/right_panel）
5. 操作意图（用户想做什么）

以JSON格式输出：
{{
  "software": "软件名称",
  "action_type": "click",
  "target_element": {{
    "type": "button",
    "name": "元素名称",
    "position_description": "位置描述",
    "region": "left_toolbar",
    "icon_description": "图标描述",
    "text_label": "文字标签（如果有）",
    "accessibility_hint": "可能的无障碍标签"
  }},
  "intent": "操作意图描述",
  "confidence": 0.9
}}
"""
    
    async def _transcribe_audio(self, audio_path: str) -> Dict:
        """
        音频转文字（使用 Whisper）
        
        Returns:
            {timestamp: text}
        """
        # TODO: 实现 Whisper 音频转文字
        # 这里先返回空字典
        return {}
    
    def _get_audio_at_time(self, transcript: Dict, timestamp: float) -> str:
        """获取指定时间的语音文字"""
        # TODO: 实现时间对齐
        return ""
    
    def _generate_mock_analysis(self, timestamp: float, audio_text: str) -> Dict:
        """生成 Mock 分析数据（用于测试）"""
        return {
            "timestamp": timestamp,
            "software": "Photoshop",
            "action_type": "click",
            "target_element": {
                "type": "tool_button",
                "name": "魔棒工具",
                "position_description": "左侧工具栏第3个",
                "region": "left_toolbar",
                "icon_description": "魔术棒形状图标",
                "text_label": None,
                "accessibility_hint": "Magic Wand Tool"
            },
            "intent": "选择魔棒工具用于选区",
            "confidence": 0.85,
            "audio_text": audio_text,
            "is_mock": True
        }
