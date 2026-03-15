use axum::{routing::get, Json, Router};
use serde_json::{json, Value};
use std::net::SocketAddr;

#[tokio::main]
async fn main() {
    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "${{ values.port }}".to_string())
        .parse()
        .expect("PORT must be a number");

    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health));

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("Starting ${{ values.name }} on {addr}");
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn root() -> Json<Value> {
    Json(json!({ "message": "Hello from ${{ values.name }}" }))
}

async fn health() -> Json<Value> {
    Json(json!({ "status": "ok", "service": "${{ values.name }}" }))
}
