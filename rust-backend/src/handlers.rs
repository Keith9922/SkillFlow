use axum::{
    extract::{Query, State},
    http::StatusCode,
    Json,
    response::IntoResponse,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::sync::Arc;
use std::env;
use crate::{
    domain::task::TaskStatus,
    service::{task_service::MemTaskService, process},
};

#[derive(Clone)]
pub struct AppState {
    pub task_service: MemTaskService,
}

// Request/Response Structs

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub components: Components,
}

#[derive(Serialize)]
pub struct Components {
    pub parse: ComponentStatus,
    pub compose: ComponentStatus,
}

#[derive(Serialize)]
pub struct ComponentStatus {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Serialize)]
pub struct CreateTaskResponse {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    pub status: String, // Changed to String to match "created" requirement
}

#[derive(Deserialize)]
pub struct ParseAudioRequest {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    // Removed dirLocation
    #[serde(rename = "audioUrl")]
    pub audio_url: String,
}

#[derive(Deserialize)]
pub struct ParseVideoRequest {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    // Removed dirLocation
    #[serde(rename = "transcriptText")]
    pub transcript_text: String,
    #[serde(rename = "videoUrl")]
    pub video_url: String,
}

#[derive(Deserialize)]
pub struct TaskStatusRequest {
    #[serde(rename = "entryId")]
    pub entry_id: String,
}

#[derive(Serialize)]
pub struct TaskStatusResponse {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    pub status: TaskStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Deserialize)]
pub struct ArtifactRequest {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    pub track: String,
}

#[derive(Serialize)]
pub struct ArtifactResponse {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    pub track: String,
    pub data: Value,
}

#[derive(Serialize)]
pub struct ListTasksResponse {
    pub count: usize,
    pub tasks: Vec<TaskSummary>,
}

#[derive(Serialize)]
pub struct TaskSummary {
    #[serde(rename = "entryId")]
    pub entry_id: String,
    pub status: TaskStatus,
}

// Handlers

pub async fn health_check() -> impl IntoResponse {
    // Check Parse module (depends on OpenRouter API Key)
    let parse_status = match env::var("OPENROUTER_API_KEY") {
        Ok(_) => ComponentStatus { status: "healthy".to_string(), message: None },
        Err(_) => ComponentStatus { status: "degraded".to_string(), message: Some("OPENROUTER_API_KEY missing".to_string()) },
    };

    // Check Compose module (Simulated/Ready)
    // Currently compose is integrated/simulated, so we consider it healthy if the service is running
    let compose_status = ComponentStatus { status: "healthy".to_string(), message: None };

    // Overall status
    let status = if parse_status.status == "healthy" && compose_status.status == "healthy" {
        "healthy".to_string()
    } else {
        "degraded".to_string()
    };

    Json(HealthResponse {
        status,
        components: Components {
            parse: parse_status,
            compose: compose_status,
        }
    })
}

pub async fn create_task(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let task = state.task_service.create_task("".to_string()); // No directory needed initially
    Json(CreateTaskResponse {
        entry_id: task.entry_id,
        status: "created".to_string(),
    })
}

pub async fn parse_audio(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<ParseAudioRequest>,
) -> impl IntoResponse {
    let entry_id = payload.entry_id.clone();
    
    // Check if task exists
    if state.task_service.get_task(&entry_id).is_none() {
        return (StatusCode::NOT_FOUND, "Task not found").into_response();
    }

    // Update status to processing (if not already)
    let _ = state.task_service.set_status(&entry_id, TaskStatus::Processing);

    // Spawn async task
    let task_service = state.task_service.clone();
    let audio_url = payload.audio_url.clone();
    
    tokio::spawn(async move {
        match process::process_audio(audio_url).await {
            Ok(result) => {
                let _ = task_service.update_audio_result(&entry_id, result.original_text);
            }
            Err(e) => {
                let _ = task_service.mark_as_failed(&entry_id, e.to_string());
            }
        }
    });

    (StatusCode::OK, Json(json!({"status": "processing"}))).into_response()
}

pub async fn parse_video(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<ParseVideoRequest>,
) -> impl IntoResponse {
    let entry_id = payload.entry_id.clone();

    // Check if task exists
    if state.task_service.get_task(&entry_id).is_none() {
        return (StatusCode::NOT_FOUND, "Task not found").into_response();
    }

    // Update status to processing
    let _ = state.task_service.set_status(&entry_id, TaskStatus::Processing);

    // Spawn async task
    let task_service = state.task_service.clone();
    let video_url = payload.video_url.clone();
    let prompt = payload.transcript_text.clone(); // Using transcript as prompt/context
    
    tokio::spawn(async move {
        match process::process_video(video_url, prompt).await {
            Ok(skill) => {
                // Serialize skill to Value
                let skill_value = serde_json::to_value(skill).unwrap_or(Value::Null);
                let _ = task_service.update_video_result(&entry_id, skill_value);
                
                // For this pipeline, we assume Steps Engine is part of this or triggered here.
                // The diagram shows "Steps Engine" as a separate participant, but also says:
                // "Status may transition to finished when all tracks are ready."
                // For now, let's mark it as Finished when video is done, assuming video analysis *is* the main output or triggers the next step.
                // Or we can leave it at VideoDone and require a separate step.
                // The diagram says: API -> STEPS : Generate steps.
                // Since we don't have a separate STEPS engine, we can simulate it or just stop at VideoDone.
                // Let's stop at VideoDone as per current code capabilities.
            }
            Err(e) => {
                let _ = task_service.mark_as_failed(&entry_id, e.to_string());
            }
        }
    });

    (StatusCode::OK, Json(json!({"status": "processing"}))).into_response()
}

pub async fn get_task_status(
    State(state): State<Arc<AppState>>,
    Query(params): Query<TaskStatusRequest>,
) -> impl IntoResponse {
    match state.task_service.get_task(&params.entry_id) {
        Some(task) => Json(TaskStatusResponse {
            entry_id: task.entry_id,
            status: task.status,
            error: task.error,
        }).into_response(),
        None => (StatusCode::NOT_FOUND, "Task not found").into_response(),
    }
}

pub async fn get_artifact(
    State(state): State<Arc<AppState>>,
    Query(params): Query<ArtifactRequest>,
) -> impl IntoResponse {
    let task = match state.task_service.get_task(&params.entry_id) {
        Some(t) => t,
        None => return (StatusCode::NOT_FOUND, "Task not found").into_response(),
    };

    let data = match params.track.as_str() {
        "audio" => match task.transcript_text {
            Some(text) => json!(text),
            None => return (StatusCode::NOT_FOUND, "Artifact not ready").into_response(),
        },
        "video" => match task.video_analysis {
            Some(analysis) => analysis,
            None => return (StatusCode::NOT_FOUND, "Artifact not ready").into_response(),
        },
        "steps" => match task.steps_package {
            Some(steps) => steps,
            None => return (StatusCode::NOT_FOUND, "Artifact not ready").into_response(),
        },
        _ => return (StatusCode::BAD_REQUEST, "Invalid track").into_response(),
    };

    Json(ArtifactResponse {
        entry_id: task.entry_id,
        track: params.track,
        data,
    }).into_response()
}

pub async fn list_tasks(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let tasks = state.task_service.list_tasks();
    let summaries: Vec<TaskSummary> = tasks.into_iter().map(|t| TaskSummary {
        entry_id: t.entry_id,
        status: t.status,
    }).collect();

    Json(ListTasksResponse {
        count: summaries.len(),
        tasks: summaries,
    })
}
