"""
步骤生成器测试
"""
import pytest
from services.step_generator import StepGenerator

@pytest.mark.asyncio
async def test_generate_skill():
    """测试技能生成"""
    generator = StepGenerator()
    
    # Mock 分析结果
    analysis_results = [
        {
            "timestamp": 1.0,
            "software": "Photoshop",
            "action_type": "click",
            "target_element": {
                "type": "tool_button",
                "name": "魔棒工具",
                "position_description": "左侧工具栏第3个",
                "region": "left_toolbar",
                "icon_description": "魔术棒形状",
                "text_label": None,
                "accessibility_hint": "Magic Wand Tool"
            },
            "intent": "选择魔棒工具",
            "confidence": 0.9
        },
        {
            "timestamp": 2.0,
            "software": "Photoshop",
            "action_type": "click",
            "target_element": {
                "type": "canvas",
                "name": "背景区域",
                "position_description": "画布中心",
                "region": "center_canvas"
            },
            "intent": "点击背景选区",
            "confidence": 0.85
        }
    ]
    
    skill_data = await generator.generate_skill(analysis_results)
    
    assert skill_data["software"] == "Photoshop"
    assert skill_data["total_steps"] == 2
    assert len(skill_data["steps"]) == 2
    assert skill_data["steps"][0]["step_id"] == 1
    assert skill_data["steps"][0]["action_type"] == "click"

def test_merge_similar_steps():
    """测试合并相似步骤"""
    generator = StepGenerator()
    
    results = [
        {
            "action_type": "click",
            "target_element": {"name": "按钮A"},
            "confidence": 0.9
        },
        {
            "action_type": "click",
            "target_element": {"name": "按钮A"},
            "confidence": 0.9
        },
        {
            "action_type": "click",
            "target_element": {"name": "按钮B"},
            "confidence": 0.9
        }
    ]
    
    merged = generator._merge_similar_steps(results)
    assert len(merged) == 2  # 应该合并为2个步骤

def test_generate_locators():
    """测试定位器生成"""
    generator = StepGenerator()
    
    target = {
        "accessibility_hint": "Magic Wand Tool",
        "text_label": "魔棒",
        "position_description": "左侧工具栏第3个",
        "region": "left_toolbar",
        "icon_description": "魔术棒形状"
    }
    
    locators = generator._generate_locators(target)
    
    assert len(locators) == 4
    assert locators[0]["method"] == "accessibility"
    assert locators[0]["priority"] == 1
    assert locators[1]["method"] == "text"
    assert locators[2]["method"] == "position"
    assert locators[3]["method"] == "visual"
