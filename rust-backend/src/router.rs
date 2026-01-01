use axum::{
    Router,
    routing::{get, post},
};
use std::sync::Arc;
use crate::handlers::{self, AppState};

pub fn create_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(handlers::health_check))
        // V1 API
        .route("/v1/tasks/create", post(handlers::create_task))
        .route("/v1/tasks/status", get(handlers::get_task_status))
        .route("/v1/tasks/artifact", get(handlers::get_artifact))
        .route("/v1/tasks/list", get(handlers::list_tasks))
        .route("/v1/parse/audio", post(handlers::parse_audio))
        .route("/v1/parse/video", post(handlers::parse_video))
        .with_state(state)
}
