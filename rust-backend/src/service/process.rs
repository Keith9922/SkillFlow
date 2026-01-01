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

use reqwest::multipart;

pub async fn process_audio(audio_url: String) -> Result<AudioAnalysisResult, Box<dyn std::error::Error>> {
    // SiliconFlow API Key
    let api_key = "sk-hvmvjwljevimjtluwqjmxcbxkznkopthjjpyzotamnqcympy";
    let client = reqwest::Client::new();

    // 1. Download Audio
    println!("[Audio Process] Downloading audio from: {}", audio_url);
    let audio_response = reqwest::get(&audio_url).await?;
    if !audio_response.status().is_success() {
         return Err(format!("Failed to download audio: {}", audio_response.status()).into());
    }
    let audio_bytes = audio_response.bytes().await?;
    let filename = audio_url.split('/').last().unwrap_or("audio.mp3").to_string();

    // 2. Prepare Multipart
    // Note: Assuming MP3 or similar. MIME type guessing could be improved but simple one works for many APIs.
    let part = multipart::Part::bytes(audio_bytes.to_vec())
        .file_name(filename)
        .mime_str("audio/mpeg")?; 
    
    let form = multipart::Form::new()
        .text("model", "TeleAI/TeleSpeechASR")
        .part("file", part);

    // 3. Send Request
    let api_url = "https://api.siliconflow.cn/v1/audio/transcriptions";
    println!("[Audio Process] Sending request to SiliconFlow: {}", api_url);

    let response = client.post(api_url)
        .header("Authorization", format!("Bearer {}", api_key))
        .multipart(form)
        .send()
        .await?;

    if !response.status().is_success() {
        let error_text = response.text().await?;
        println!("[Audio Process] API Error Response: {}", error_text);
        return Err(format!("API request failed: {}", error_text).into());
    }

    let response_json: Value = response.json().await?;
    println!("[Audio Process] Response JSON: {}", serde_json::to_string_pretty(&response_json).unwrap());

    // 4. Parse Result
    let text = response_json["text"].as_str().unwrap_or("").to_string();

    Ok(AudioAnalysisResult {
        original_text: text,
        summary_info: "Transcribed by TeleSpeechASR".to_string(),
    })
}

use std::path::Path;

async fn analyze_video_content(video_url: String, user_prompt: String) -> Result<String, Box<dyn std::error::Error>> {
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

    println!("[Video Analysis] Request Payload: {}", serde_json::to_string_pretty(&payload).unwrap());

    let response = client.post(OPENROUTER_API_URL)
        .json(&payload)
        .send()
        .await?;

    if !response.status().is_success() {
        let error_text = response.text().await?;
        println!("[Video Analysis] API Error Response: {}", error_text);
        return Err(format!("API request failed: {}", error_text).into());
    }

    let response_json: Value = response.json().await?;
    println!("[Video Analysis] Response JSON: {}", serde_json::to_string_pretty(&response_json).unwrap());
    
    let content = response_json["choices"][0]["message"]["content"]
        .as_str()
        .ok_or("No content in response")?;

    // Return the raw content (which might be an escaped JSON string)
    Ok(content.to_string())
}

async fn format_skill_with_llm(raw_content: String) -> Result<Skill, Box<dyn std::error::Error>> {
    let api_key = get_api_key()?;
    let client = create_client(&api_key).await;

    // Read schema file
    let schema_path = "/root/srcs/SkillFlow/rust-backend/schema.json";
    let schema_content = tokio::fs::read_to_string(schema_path).await.unwrap_or_else(|_| "{}".to_string());

    let system_prompt = format!(
        "You are a strict JSON formatter. \
        Your goal is to convert the input text (which contains a JSON representation of a Skill) into a perfectly formatted JSON object that adheres to the provided Schema. \
        \n\nSchema Definition:\n{}\n\n \
        Rules:\n \
        1. Fix any malformed JSON.\n \
        2. Ensure the structure matches the Schema (especially 'steps', 'selectors' etc. if applicable, though the input might use a slightly different 'Skill' model, try to map it to valid JSON).\n \
        3. Return ONLY the valid JSON string, no markdown, no explanations.",
        schema_content
    );

    let payload = json!({
        "model": "z-ai/glm-4.7",
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": raw_content
            }
        ]
    });

    println!("[Skill Formatting] Request Payload sent to GLM-4.7");

    let response = client.post(OPENROUTER_API_URL)
        .json(&payload)
        .send()
        .await?;

    if !response.status().is_success() {
        let error_text = response.text().await?;
        println!("[Skill Formatting] API Error Response: {}", error_text);
        return Err(format!("Formatting API request failed: {}", error_text).into());
    }

    let response_json: Value = response.json().await?;
    println!("[Skill Formatting] Response JSON: {}", serde_json::to_string_pretty(&response_json).unwrap());

    let content = response_json["choices"][0]["message"]["content"]
        .as_str()
        .ok_or("No content in response")?;

    let clean_content = content.trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```");

    let package: crate::domain::package::Package = serde_json::from_str(clean_content)?;
    
    // Map Package to Skill
    // Note: Skill struct in domain/skill.rs is different from Package struct in domain/package.rs
    // The previous implementation expected Skill directly.
    // Since we are now using schema.json which defines Package, GLM returns Package.
    // We need to convert Package to Skill or update Skill definition.
    // Given the task is to fix "missing field `type`" error which likely comes from Skill vs Package mismatch,
    // and the user input shows GLM outputting "Package" format.
    // Let's assume we need to return a Skill object as per function signature.
    
    // Create a simplified Skill from Package
    let skill = Skill {
        skill_id: package.package.name.clone(), // Using name as ID for now or generate one
        name: package.package.name,
        software: package.app.name,
        version: package.version,
        description: package.package.description.unwrap_or_default(),
        steps: package.steps.into_iter().enumerate().map(|(i, s)| {
            use crate::domain::skill::{Step, Target, Locator, ActionType, TargetType, LocatorMethod};
            use crate::domain::package::StepOperation;
            
            let empty_ref = crate::domain::package::SelectorOrRef::Ref(crate::domain::package::SelectorRef { reference: "".to_string() });
            
            let (action_type, target_val) = match &s.op {
                StepOperation::Click(c) => (ActionType::Click, &c.target),
                StepOperation::Type(t) => (ActionType::Input, t.target.as_ref().unwrap_or(&empty_ref)),
                StepOperation::Drag(d) => (ActionType::Drag, &d.from),
                StepOperation::Scroll(sc) => (ActionType::Drag, sc.target.as_ref().unwrap_or(&empty_ref)),
                StepOperation::Hotkey(_) => (ActionType::Shortcut, &empty_ref),
                StepOperation::Wait(w) => (ActionType::Menu, &w.until),
                StepOperation::Assert(a) => (ActionType::Menu, &a.expect),
            };

            // Extract target name from ref or inline
            let target_name = match target_val {
                crate::domain::package::SelectorOrRef::Ref(r) => r.reference.trim_start_matches("#/selectors/").to_string(),
                _ => "inline_target".to_string(),
            };

            Step {
                step_id: (i + 1) as u32,
                action_type,
                target: Target {
                    target_type: TargetType::Button, // Defaulting
                    name: target_name,
                    locators: vec![
                        Locator {
                            method: LocatorMethod::Text,
                            value: json!(""),
                            priority: 1,
                        }
                    ],
                },
                instruction: s.name.unwrap_or_else(|| format!("Step {}", i+1)),
                wait_after: 0.0,
                parameters: json!({}),
                confidence: 1.0,
            }
        }).collect(),
        total_steps: 0, // Will update
        estimated_duration: 0,
        tags: package.package.tags,
        created_at: None,
        source_type: crate::domain::skill::SourceType::VideoAnalysis,
    };
    
    let mut final_skill = skill;
    final_skill.total_steps = final_skill.steps.len() as u32;

    Ok(final_skill)
}

pub async fn process_video(video_url: String, user_prompt: String) -> Result<Skill, Box<dyn std::error::Error>> {
    // 1. Analyze video with Seed model
    let raw_analysis = analyze_video_content(video_url, user_prompt).await?;
    
    // 2. Format output with GLM-4.7 using Schema
    let formatted_skill = format_skill_with_llm(raw_analysis).await?;
    
    Ok(formatted_skill)
}
