use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use chrono::Utc;
use crate::domain::task::{Task, TaskStatus};

#[derive(Debug, Clone)]
pub struct MemTaskService {
    tasks: Arc<Mutex<HashMap<String, Task>>>,
}

impl MemTaskService {
    pub fn new() -> Self {
        Self {
            tasks: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn create_task(&self, dir_location: String) -> Task {
        let entry_id = Uuid::new_v4().to_string();
        let task = Task::new(entry_id.clone(), dir_location);
        
        let mut tasks = self.tasks.lock().unwrap();
        tasks.insert(entry_id.clone(), task.clone());
        
        task
    }

    pub fn get_task(&self, entry_id: &str) -> Option<Task> {
        let tasks = self.tasks.lock().unwrap();
        tasks.get(entry_id).cloned()
    }

    pub fn set_status(&self, entry_id: &str, status: TaskStatus) -> Result<Task, String> {
        let mut tasks = self.tasks.lock().unwrap();
        if let Some(task) = tasks.get_mut(entry_id) {
            task.status = status;
            task.updated_at = Utc::now();
            Ok(task.clone())
        } else {
            Err("Task not found".to_string())
        }
    }

    pub fn update_audio_result(&self, entry_id: &str, transcript: String) -> Result<Task, String> {
        let mut tasks = self.tasks.lock().unwrap();
        if let Some(task) = tasks.get_mut(entry_id) {
            task.transcript_text = Some(transcript);
            task.status = TaskStatus::AudioDone;
            task.updated_at = Utc::now();
            Ok(task.clone())
        } else {
            Err("Task not found".to_string())
        }
    }

    pub fn update_video_result(&self, entry_id: &str, analysis: serde_json::Value) -> Result<Task, String> {
        let mut tasks = self.tasks.lock().unwrap();
        if let Some(task) = tasks.get_mut(entry_id) {
            // Business Rule: Should ideally check if AudioDone or Processing?
            // The diagram implies Video follows Audio, but they could be independent in some architectures.
            // For this specific pipeline, Client submits transcript to video parse, implying dependency.
            // We'll allow transition from any non-terminal state for flexibility, but update status to VideoDone.
            
            task.video_analysis = Some(analysis);
            task.status = TaskStatus::VideoDone;
            task.updated_at = Utc::now();
            Ok(task.clone())
        } else {
            Err("Task not found".to_string())
        }
    }

    pub fn update_steps_result(&self, entry_id: &str, steps: serde_json::Value) -> Result<Task, String> {
        let mut tasks = self.tasks.lock().unwrap();
        if let Some(task) = tasks.get_mut(entry_id) {
            task.steps_package = Some(steps);
            task.status = TaskStatus::Finished;
            task.updated_at = Utc::now();
            Ok(task.clone())
        } else {
            Err("Task not found".to_string())
        }
    }

    pub fn mark_as_failed(&self, entry_id: &str, error: String) -> Result<Task, String> {
        let mut tasks = self.tasks.lock().unwrap();
        if let Some(task) = tasks.get_mut(entry_id) {
            task.error = Some(error);
            task.status = TaskStatus::Failed;
            task.updated_at = Utc::now();
            Ok(task.clone())
        } else {
            Err("Task not found".to_string())
        }
    }

    pub fn list_tasks(&self) -> Vec<Task> {
        let tasks = self.tasks.lock().unwrap();
        tasks.values().cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_create_task() {
        let service = MemTaskService::new();
        let task = service.create_task("s3://bucket/prefix/".to_string());
        
        assert_eq!(task.dir_location, "s3://bucket/prefix/");
        assert_eq!(task.status, TaskStatus::Created);
        assert!(service.get_task(&task.entry_id).is_some());
    }

    #[test]
    fn test_full_flow() {
        let service = MemTaskService::new();
        let task = service.create_task("s3://test".to_string());
        let id = task.entry_id;

        // 1. Audio Done
        let task = service.update_audio_result(&id, "Hello World".to_string()).unwrap();
        assert_eq!(task.status, TaskStatus::AudioDone);
        assert_eq!(task.transcript_text, Some("Hello World".to_string()));

        // 2. Video Done
        let analysis = json!({"scenes": []});
        let task = service.update_video_result(&id, analysis.clone()).unwrap();
        assert_eq!(task.status, TaskStatus::VideoDone);
        assert_eq!(task.video_analysis, Some(analysis));

        // 3. Finished (Steps)
        let steps = json!({"steps": []});
        let task = service.update_steps_result(&id, steps.clone()).unwrap();
        assert_eq!(task.status, TaskStatus::Finished);
        assert_eq!(task.steps_package, Some(steps));
    }

    #[test]
    fn test_failure_flow() {
        let service = MemTaskService::new();
        let task = service.create_task("s3://fail".to_string());
        let id = task.entry_id;

        let task = service.mark_as_failed(&id, "Something went wrong".to_string()).unwrap();
        assert_eq!(task.status, TaskStatus::Failed);
        assert_eq!(task.error, Some("Something went wrong".to_string()));
    }
}
