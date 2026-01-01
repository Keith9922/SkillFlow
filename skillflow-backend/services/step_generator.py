"""
步骤生成器
将 AI 分析结果转换为可执行的技能步骤
"""
from typing import List, Dict, Optional
import uuid

class StepGenerator:
    """步骤生成器"""
    
    def __init__(self):
        self.min_confidence = 0.7  # 最低置信度阈值
    
    async def generate_skill(
        self,
        analysis_results: List[Dict],
        target_software: Optional[str] = None
    ) -> Dict:
        """
        生成技能数据
        
        Args:
            analysis_results: AI 分析结果列表
            target_software: 目标软件（可选）
        
        Returns:
            技能 JSON 数据
        """
        # 1. 过滤低置信度结果
        filtered_results = [
            r for r in analysis_results
            if r.get("confidence", 0) >= self.min_confidence
        ]
        
        # 2. 识别软件
        software = target_software or self._identify_software(filtered_results)
        
        # 3. 合并连续相同操作
        merged_steps = self._merge_similar_steps(filtered_results)
        
        # 4. 生成步骤序列
        steps = self._generate_steps(merged_steps)
        
        # 5. 生成技能元数据
        skill_data = {
            "skill_id": str(uuid.uuid4()),
            "name": self._generate_skill_name(steps, software),
            "software": software,
            "version": "any",
            "description": self._generate_description(steps),
            "steps": steps,
            "total_steps": len(steps),
            "estimated_duration": len(steps) * 3,  # 估算时长（秒）
            "tags": self._generate_tags(software, steps),
            "created_at": None,  # 前端填充
            "source_type": "video_analysis"
        }
        
        return skill_data
    
    def _identify_software(self, results: List[Dict]) -> str:
        """识别目标软件"""
        # 统计出现最多的软件名
        software_counts = {}
        for r in results:
            software = r.get("software", "Unknown")
            software_counts[software] = software_counts.get(software, 0) + 1
        
        if software_counts:
            return max(software_counts, key=software_counts.get)
        return "Unknown"
    
    def _merge_similar_steps(self, results: List[Dict]) -> List[Dict]:
        """合并连续相同的操作"""
        if not results:
            return []
        
        merged = []
        current = results[0]
        
        for next_result in results[1:]:
            # 如果是相同的操作，跳过
            if self._is_similar_action(current, next_result):
                continue
            else:
                merged.append(current)
                current = next_result
        
        merged.append(current)
        return merged
    
    def _is_similar_action(self, a: Dict, b: Dict) -> bool:
        """判断两个操作是否相似"""
        return (
            a.get("action_type") == b.get("action_type") and
            a.get("target_element", {}).get("name") == b.get("target_element", {}).get("name")
        )
    
    def _generate_steps(self, merged_results: List[Dict]) -> List[Dict]:
        """生成步骤列表"""
        steps = []
        
        for idx, result in enumerate(merged_results, 1):
            target = result.get("target_element", {})
            
            step = {
                "step_id": idx,
                "action_type": result.get("action_type", "click"),
                "target": {
                    "type": target.get("type", "button"),
                    "name": target.get("name", "Unknown"),
                    
                    # 多重定位策略
                    "locators": self._generate_locators(target)
                },
                "instruction": result.get("intent", "执行操作"),
                "wait_after": 0.5,  # 操作后等待时间
                "parameters": {},
                "confidence": result.get("confidence", 0.8)
            }
            
            steps.append(step)
        
        return steps
    
    def _generate_locators(self, target: Dict) -> List[Dict]:
        """生成多重定位器"""
        locators = []
        
        # 1. Accessibility 定位（最优先）
        if target.get("accessibility_hint"):
            locators.append({
                "method": "accessibility",
                "value": target["accessibility_hint"],
                "priority": 1
            })
        
        # 2. 文字定位
        if target.get("text_label"):
            locators.append({
                "method": "text",
                "value": target["text_label"],
                "priority": 2
            })
        
        # 3. 位置定位
        if target.get("position_description"):
            locators.append({
                "method": "position",
                "value": {
                    "description": target["position_description"],
                    "region": target.get("region", "unknown")
                },
                "priority": 3
            })
        
        # 4. 视觉定位（最后手段）
        if target.get("icon_description"):
            locators.append({
                "method": "visual",
                "value": {
                    "icon_description": target["icon_description"],
                    "template_image": None  # TODO: 保存模板图片
                },
                "priority": 4
            })
        
        return locators
    
    def _generate_skill_name(self, steps: List[Dict], software: str) -> str:
        """生成技能名称"""
        if not steps:
            return f"{software} 操作"
        
        # 基于第一个和最后一个步骤生成名称
        first_intent = steps[0].get("instruction", "")
        last_intent = steps[-1].get("instruction", "")
        
        if "换底" in first_intent or "换底" in last_intent:
            return f"{software} 证件照换底色"
        elif "透视" in first_intent or "透视" in last_intent:
            return f"{software} 数据透视表"
        else:
            return f"{software} 操作流程"
    
    def _generate_description(self, steps: List[Dict]) -> str:
        """生成技能描述"""
        return f"包含 {len(steps)} 个操作步骤的自动化流程"
    
    def _generate_tags(self, software: str, steps: List[Dict]) -> List[str]:
        """生成标签"""
        tags = [software.lower()]
        
        # 基于步骤内容添加标签
        all_text = " ".join([
            step.get("instruction", "") for step in steps
        ])
        
        if "换底" in all_text:
            tags.append("换底色")
        if "透视" in all_text:
            tags.append("数据透视")
        if "图片" in all_text or "照片" in all_text:
            tags.append("图片处理")
        
        return tags
