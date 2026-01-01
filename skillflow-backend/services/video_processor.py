"""
视频处理服务
负责下载视频、抽帧、提取音频
"""
import os
import cv2
import numpy as np
import yt_dlp
import ffmpeg
from typing import List, Tuple
import tempfile
import asyncio
from pathlib import Path

class VideoProcessor:
    """视频处理器"""
    
    def __init__(self, temp_dir: str = "./temp"):
        self.temp_dir = Path(temp_dir)
        self.temp_dir.mkdir(exist_ok=True)
        self.frame_rate = 1.5  # 每秒抽取帧数
        self.change_threshold = 0.05  # 画面变化阈值
    
    async def download_video(self, video_url: str) -> str:
        """
        下载视频
        支持 B站、抖音、YouTube 等平台
        """
        try:
            # 使用 yt-dlp 下载
            ydl_opts = {
                'format': 'best[ext=mp4]',
                'outtmpl': str(self.temp_dir / '%(id)s.%(ext)s'),
                'quiet': True,
                'no_warnings': True,
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(video_url, download=True)
                video_path = ydl.prepare_filename(info)
            
            return video_path
            
        except Exception as e:
            raise Exception(f"视频下载失败: {str(e)}")
    
    async def extract_key_frames(
        self,
        video_path: str,
        max_frames: int = 100
    ) -> List[Tuple[float, np.ndarray]]:
        """
        提取关键帧（智能抽帧）
        只保留画面变化明显的帧
        
        Returns:
            List[(timestamp, frame)]
        """
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        frames = []
        prev_frame = None
        frame_count = 0
        
        # 计算采样间隔
        sample_interval = max(1, int(fps / self.frame_rate))
        
        while cap.isOpened() and len(frames) < max_frames:
            ret, frame = cap.read()
            if not ret:
                break
            
            frame_count += 1
            
            # 按间隔采样
            if frame_count % sample_interval != 0:
                continue
            
            # 计算与上一帧的差异
            if prev_frame is not None:
                # 转灰度图计算差异
                gray_curr = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                gray_prev = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
                
                diff = cv2.absdiff(gray_curr, gray_prev)
                change_ratio = np.sum(diff) / (diff.shape[0] * diff.shape[1] * 255)
                
                # 只保存变化明显的帧
                if change_ratio > self.change_threshold:
                    timestamp = frame_count / fps
                    frames.append((timestamp, frame.copy()))
                    prev_frame = frame.copy()
            else:
                # 第一帧总是保存
                timestamp = frame_count / fps
                frames.append((timestamp, frame.copy()))
                prev_frame = frame.copy()
        
        cap.release()
        
        print(f"从 {total_frames} 帧中提取了 {len(frames)} 个关键帧")
        return frames
    
    async def extract_audio(self, video_path: str) -> str:
        """
        提取音频
        """
        try:
            audio_path = str(self.temp_dir / f"{Path(video_path).stem}.wav")
            
            # 使用 ffmpeg 提取音频
            stream = ffmpeg.input(video_path)
            stream = ffmpeg.output(stream, audio_path, acodec='pcm_s16le', ac=1, ar='16k')
            ffmpeg.run(stream, overwrite_output=True, quiet=True)
            
            return audio_path
            
        except Exception as e:
            print(f"音频提取失败: {str(e)}")
            return None
    
    def cleanup(self, *paths):
        """清理临时文件"""
        for path in paths:
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception as e:
                    print(f"清理文件失败 {path}: {e}")
