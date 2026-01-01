use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Processing,
    AudioDone,
    VideoDone,
    Finished,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub entry_id: String,
    pub dir_location: String,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub transcript_text: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub video_analysis: Option<serde_json::Value>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub steps_package: Option<serde_json::Value>,
    
    pub status: TaskStatus,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Task {
    pub fn new(entry_id: String, dir_location: String) -> Self {
        let now = Utc::now();
        Self {
            entry_id,
            dir_location,
            transcript_text: None,
            video_analysis: None,
            steps_package: None,
            status: TaskStatus::Processing,
            error: None,
            created_at: now,
            updated_at: now,
        }
    }
}
