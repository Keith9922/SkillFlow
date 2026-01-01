use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum SourceType {
    VideoAnalysis,
    Manual,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ActionType {
    Click,
    Input,
    Drag,
    Shortcut,
    Menu,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum TargetType {
    Button,
    ToolButton,
    MenuItem,
    InputField,
    Icon,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum LocatorMethod {
    Accessibility,
    Text,
    Position,
    Visual,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Locator {
    pub method: LocatorMethod,
    /// Can be a string or an object depending on the method
    pub value: Value,
    pub priority: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Target {
    #[serde(rename = "type")]
    pub target_type: TargetType,
    pub name: String,
    pub locators: Vec<Locator>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Step {
    pub step_id: u32,
    pub action_type: ActionType,
    pub target: Target,
    pub instruction: String,
    pub wait_after: f32,
    /// Extra parameters like input content, drag distance, etc.
    #[serde(default)]
    pub parameters: Value,
    pub confidence: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Skill {
    pub skill_id: String,
    pub name: String,
    pub software: String,
    pub version: String,
    pub description: String,
    pub steps: Vec<Step>,
    pub total_steps: u32,
    pub estimated_duration: u32,
    pub tags: Vec<String>,
    pub created_at: Option<DateTime<Utc>>,
    pub source_type: SourceType,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::from_str;

    #[test]
    fn test_skill_deserialization() {
        let json_data = r#"
        {
            "skill_id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Photoshop 证件照换底色",
            "software": "Photoshop",
            "version": "any",
            "description": "包含 8 个操作步骤的自动化流程",
            "steps": [
                {
                    "step_id": 1,
                    "action_type": "click",
                    "target": {
                        "type": "tool_button",
                        "name": "魔棒工具",
                        "locators": [
                            {
                                "method": "accessibility",
                                "value": "Magic Wand Tool",
                                "priority": 1
                            },
                            {
                                "method": "position",
                                "value": {
                                    "description": "左侧工具栏第3个",
                                    "region": "left_toolbar"
                                },
                                "priority": 3
                            },
                            {
                                "method": "visual",
                                "value": {
                                    "icon_description": "魔术棒形状图标",
                                    "template_image": null
                                },
                                "priority": 4
                            }
                        ]
                    },
                    "instruction": "选择魔棒工具用于选区",
                    "wait_after": 0.5,
                    "parameters": {},
                    "confidence": 0.85
                }
            ],
            "total_steps": 8,
            "estimated_duration": 24,
            "tags": ["photoshop", "换底色", "图片处理"],
            "created_at": null,
            "source_type": "video_analysis"
        }
        "#;

        let skill: Skill = from_str(json_data).expect("Failed to deserialize Skill");

        assert_eq!(skill.skill_id, "550e8400-e29b-41d4-a716-446655440000");
        assert_eq!(skill.name, "Photoshop 证件照换底色");
        assert_eq!(skill.software, "Photoshop");
        assert_eq!(skill.version, "any");
        assert_eq!(skill.steps.len(), 1);
        assert_eq!(skill.total_steps, 8);
        assert_eq!(skill.source_type, SourceType::VideoAnalysis);
        
        let step = &skill.steps[0];
        assert_eq!(step.step_id, 1);
        assert_eq!(step.action_type, ActionType::Click);
        assert_eq!(step.target.target_type, TargetType::ToolButton);
        assert_eq!(step.target.locators.len(), 3);
        
        let locator1 = &step.target.locators[0];
        assert_eq!(locator1.method, LocatorMethod::Accessibility);
        assert_eq!(locator1.value.as_str().unwrap(), "Magic Wand Tool");
    }
}
