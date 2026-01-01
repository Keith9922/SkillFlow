use crate::domain::skill::Skill;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::env;

#[derive(Debug, Serialize, Deserialize)]
pub struct AudioAnalysisResult {
    pub original_text: String,
    pub summary_info: String,
}

const OPENROUTER_API_URL: &str = "https://openrouter.ai/api/v1/chat/completions";

fn get_api_key() -> Result<String, String> {
    env::var("OPENROUTER_API_KEY").map_err(|_| "OPENROUTER_API_KEY not set".to_string())
}

async fn create_client(api_key: &str) -> reqwest::Client {
    let mut headers = HeaderMap::new();
    headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    let mut auth_value = HeaderValue::from_str(&format!("Bearer {}", api_key)).expect("Invalid API Key");
    auth_value.set_sensitive(true);
    headers.insert(AUTHORIZATION, auth_value);

    reqwest::Client::builder()
        .default_headers(headers)
        .build()
        .expect("Failed to build client")
}

pub async fn process_audio(audio_url: String) -> Result<AudioAnalysisResult, Box<dyn std::error::Error>> {
    let api_key = get_api_key()?;
    let client = create_client(&api_key).await;

    let system_prompt = "You are an audio processing assistant. \
    Transcribe the input audio and extract key information such as operation steps and usage environment. \
    Return the result in strictly valid JSON format with keys 'original_text' and 'summary_info'. \
    Do not wrap the JSON in markdown code blocks.";

    let payload = json!({
        "model": "openai/gpt-4o-audio-preview",
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "audio_url",
                        "audio_url": {
                            "url": audio_url
                        }
                    }
                ]
            }
        ]
    });

    let response = client.post(OPENROUTER_API_URL)
        .json(&payload)
        .send()
        .await?;

    if !response.status().is_success() {
        return Err(format!("API request failed: {}", response.text().await?).into());
    }

    let response_json: Value = response.json().await?;
    
    // Parse the content from the response
    let content = response_json["choices"][0]["message"]["content"]
        .as_str()
        .ok_or("No content in response")?;

    // Try to parse JSON from the content
    // Clean up potential markdown code blocks if the model ignores the instruction
    let clean_content = content.trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```");

    let result: AudioAnalysisResult = serde_json::from_str(clean_content)?;

    Ok(result)
}

pub async fn process_video(video_url: String, user_prompt: String) -> Result<Skill, Box<dyn std::error::Error>> {
    let api_key = get_api_key()?;
    let client = create_client(&api_key).await;

    let system_prompt = "You are a video analysis assistant. \
    Analyze the video to extract mouse movements, clicks, and element details. \
    Serialize the output strictly into a JSON object matching the 'Skill' data model. \
    Ensure all fields like 'skill_id', 'steps', 'target', 'locators' are populated correctly based on the visual evidence. \
    Return ONLY the valid JSON, no markdown.";

    let payload = json!({
        "model": "bytedance-seed/seed-1.6",
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": user_prompt
                    },
                    {
                        "type": "video_url",
                        "video_url": {
                            "url": video_url
                        }
                    }
                ]
            }
        ]
    });

    let response = client.post(OPENROUTER_API_URL)
        .json(&payload)
        .send()
        .await?;

    if !response.status().is_success() {
        return Err(format!("API request failed: {}", response.text().await?).into());
    }

    let response_json: Value = response.json().await?;
    
    let content = response_json["choices"][0]["message"]["content"]
        .as_str()
        .ok_or("No content in response")?;

    let clean_content = content.trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```");

    let skill: Skill = serde_json::from_str(clean_content)?;

    Ok(skill)
}
