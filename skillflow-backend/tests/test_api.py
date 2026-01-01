"""
API 接口测试
"""
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_root():
    """测试根路径"""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_health_check():
    """测试健康检查"""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert data["status"] == "healthy"

def test_analyze_video():
    """测试视频解析接口"""
    response = client.post(
        "/api/analyze-video",
        json={
            "video_url": "https://example.com/test.mp4",
            "client_id": "test-client-123"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "task_id" in data
    assert data["status"] == "processing"

def test_test_endpoint():
    """测试测试接口"""
    response = client.get("/api/test")
    assert response.status_code == 200
    assert response.json()["message"] == "API is working!"
