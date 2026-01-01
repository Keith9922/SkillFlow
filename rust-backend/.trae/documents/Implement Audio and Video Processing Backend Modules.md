# Backend Function Implementation Plan

## 1. Project Configuration
- **Add Dependencies**:
  - `reqwest` (features: `json`, `rustls-tls`)
  - `serde_json`
  - `dotenvy`
  - (Note: `serde` is already present)

## 2. Service Implementation (`src/service/process.rs`)
- **Import Data Model**: Use `src/domain/skill.rs` for the `Skill` struct.

### OpenRouter API Integration Strategy
- **Endpoint**: `https://openrouter.ai/api/v1/chat/completions`
- **Authentication**: `Authorization: Bearer $OPENROUTER_API_KEY`
- **Request Structure**:
  ```json
  {
    "model": "<model_id>",
    "messages": [
      {
        "role": "user",
        "content": [
          { "type": "text", "text": "<prompt>" },
          { "type": "<media_type>_url", "<media_type>_url": { "url": "<url>" } }
        ]
      }
    ]
  }
  ```

### Modules
- **AudioProcess Module**:
  - **Function**: `process_audio(audio_url: String) -> Result<AudioAnalysisResult>`
  - **Model**: `openai/gpt-4o-audio-preview`
  - **Payload**:
    - `content` includes `{"type": "text", "text": "..."}` and `{"type": "audio_url", "audio_url": {"url": audio_url}}` (inferred pattern).
    - Prompt: "Transcribe the audio and extract key steps/environment."
  - **Output**: Returns `AudioAnalysisResult` with transcript and summary.

- **VideoProcess Module**:
  - **Function**: `process_video(video_url: String, prompt: String) -> Result<Skill>`
  - **Model**: `bytedance-seed/seed-1.6`
  - **Payload**:
    - `content` includes `{"type": "text", "text": prompt}` and `{"type": "video_url", "video_url": {"url": video_url}}`.
    - System/User Prompt: Explicitly requests JSON output matching the `Skill` schema.
  - **Output**: Deserializes the JSON response directly into the `Skill` struct.

## 3. Structure & Exports
- Update `src/service/mod.rs` to export the `process` module.
