mod domain;
mod handlers;
mod router;
mod service;

use std::net::SocketAddr;
use std::sync::Arc;
use tracing::info;
use service::task_service::MemTaskService;
use handlers::AppState;

#[tokio::main]
async fn main() {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    // Load environment variables (optional, assuming dotenvy usage for keys)
    let _ = dotenvy::dotenv();

    // Initialize State
    let task_service = MemTaskService::new();
    let app_state = Arc::new(AppState {
        task_service,
    });

    // 构建路由
    let app = router::create_router(app_state);

    // 定义监听地址
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    info!("listening on {}", addr);

    // 启动服务
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
