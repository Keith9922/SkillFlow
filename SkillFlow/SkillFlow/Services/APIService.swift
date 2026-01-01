//
//  APIService.swift
//  SkillFlow
//
//  Created by Trae AI on 2026/1/1.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(Int, String)
}

struct CreateTaskResponse: Codable {
    let status: String?
    let entryId: String
}

struct ParseResponse: Codable {
    let entryId: String?
    let task_id: String? // 兼容 video 接口返回的 task_id
    let status: String?
    let message: String?
}

// 通用的状态响应，包含可能的字段
struct TaskStatusResponse: Codable {
    let entryId: String?
    let status: String?
    
    // 各阶段状态 (假设字段名，根据业务逻辑推断)
    let audioStatus: String?
    let videoStatus: String?
    let stepsStatus: String?
    
    // 中间结果
    let transcriptText: String?
    // let steps: [SkillStep]? // 暂时移除，因为 SkillStep 也是 Codable，但可能需要手动导入或重新定义
    
    // 为了调试，我们添加一个解析原始数据的辅助方法
    // 实际使用时主要依赖 status 字段
    
    enum CodingKeys: String, CodingKey {
        case entryId
        case status
        case audioStatus = "audio_status"
        case videoStatus = "video_status"
        case stepsStatus = "steps_status"
        case transcriptText = "transcript_text" // 假设下划线命名
        // case steps
    }
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://api.sf.smart-teach.cn"
    
    private init() {}
    
    // MARK: - 1. Create Task
    func createTask() async throws -> String {
        let urlString = "\(baseURL)/v1/tasks/create"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        print("[APIService] GET \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateResponse(response, data: data)
        
        let result = try JSONDecoder().decode(CreateTaskResponse.self, from: data)
        return result.entryId
    }
    
    // MARK: - 2. Parse Audio
    func parseAudio(entryId: String, audioUrl: String) async throws {
        let urlString = "\(baseURL)/v1/parse/audio"
        let body: [String: String] = [
            "entryId": entryId,
            "audioUrl": audioUrl
        ]
        
        try await postRequest(urlString, body: body)
    }
    
    // MARK: - 3. Parse Video
    func parseVideo(entryId: String, videoUrl: String, transcriptText: String) async throws {
        let urlString = "\(baseURL)/v1/parse/video"
        let body: [String: String] = [
            "entryId": entryId,
            "videoUrl": videoUrl,
            "transcriptText": transcriptText
        ]
        
        try await postRequest(urlString, body: body)
    }
    
    // MARK: - 4. Generate Steps
    func generateSteps(entryId: String) async throws {
        let urlString = "\(baseURL)/v1/parse/steps"
        let body: [String: String] = [
            "entryId": entryId
        ]
        
        try await postRequest(urlString, body: body)
    }
    
    // MARK: - 5. Check Status
    func checkStatus(entryId: String) async throws -> [String: Any] {
        let urlString = "\(baseURL)/v1/tasks/status?entryId=\(entryId)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        print("[APIService] GET \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateResponse(response, data: data)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingFailed(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"]))
        }
        
        return json
    }
    
    // MARK: - 6. Get Artifact
    func getArtifact(entryId: String, track: String) async throws -> [String: Any] {
        let urlString = "\(baseURL)/v1/tasks/artifact?entryId=\(entryId)&track=\(track)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        print("[APIService] GET \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateResponse(response, data: data)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingFailed(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"]))
        }
        
        return json
    }
    
    // MARK: - 7. VLM Action Generation (Legacy)
    // 这里的 generateAction 是旧方法，保留兼容性或之后删除
    // ... (Code omitted for brevity if replacing, but we'll add new methods below)
    
    // MARK: - 8. SiliconFlow Integration
    
    /// 与 Kimi 模型对话，检测操作意图
    /// - Parameter userMessage: 用户输入
    /// - Returns: 模型回复。如果包含 [OPERATE: ...] 则表示有操作意图
    func chatWithKimi(userMessage: String, history: [Message] = []) async throws -> String {
        let urlString = "https://api.siliconflow.cn/v1/chat/completions"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let systemPrompt = """
        You are SkillFlow Assistant, a helpful AI assistant on macOS.
        
        Your primary goal is to help users. If the user asks for general information, reply normally.
        
        CRITICAL INSTRUCTION:
        If the user's message implies a need to operate the computer (e.g., "open Safari", "click the button", "search for...", "check weather app"), you MUST NOT provide a textual tutorial. Instead, you MUST output a special token to trigger the automation agent.
        
        Format for automation trigger:
        [OPERATE: <concise description of the intent>]
        
        Examples:
        User: "How are you?"
        Assistant: "I'm doing well, thank you! How can I help you today?"
        
        User: "Open Spotify and play music"
        Assistant: "[OPERATE: Open Spotify and play music]"
        
        User: "帮我查一下今天杭州的天气"
        Assistant: "[OPERATE: Check weather for Hangzhou]"
        
        Keep the intent description concise and in English if possible, or clear Chinese.
        """
        
        // 构建消息历史 (简化，取最近 5 条)
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        let recentHistory = history.suffix(5)
        for msg in recentHistory {
            messages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
            ])
        }
        
        // 当前消息
        messages.append(["role": "user", "content": userMessage])
        
        let payload: [String: Any] = [
            "model": SiliconFlowConfig.kimiModel,
            "messages": messages,
            "temperature": 0.3, // 稍微有点灵活性用于聊天
            "max_tokens": 512
        ]
        
        return try await performSiliconFlowRequest(url: url, payload: payload)
    }
    
    /// 调用 GLM-4V 生成自动化任务队列
    /// - Parameters:
    ///   - intent: 用户意图 (来自 Kimi)
    ///   - imageData: 屏幕截图数据
    /// - Returns: VLMTaskResponse (包含思考和任务列表)
    func executeVLMTask(intent: String, imageData: Data) async throws -> VLMTaskResponse {
        let urlString = "https://api.siliconflow.cn/v1/chat/completions"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let systemPrompt = """
        You are a macOS GUI Automation Expert. Your job is to analyze the screen and generate a precise JSON task queue to fulfill the user's intent.
        
        COORDINATE SYSTEM:
        - Normalized coordinates: (0, 0) is TOP-LEFT, (1, 1) is BOTTOM-RIGHT.
        - x is horizontal (0=left, 1=right).
        - y is vertical (0=top, 1=bottom).
        
        AVAILABLE TOOLS (JSON Format):
        - move_mouse: {"action": "move_mouse", "params": {"x": 0.5, "y": 0.5, "duration": 500}} (duration in ms, default 500)
        - click: {"action": "click", "params": {"button": "left"}} (options: left, right, center)
          * IMPORTANT: For double clicks, issue two "click" actions with a "delay" of 50ms in between.
        - mouse_down/up: {"action": "mouse_down", "params": {"button": "left"}}
        - paste_text: {"action": "paste_text", "params": {"text": "hello world"}}
          * PREFERRED for typing text, especially long text or Chinese. Ensure the text field is focused (clicked) before pasting.
        - key_press: {"action": "key_press", "params": {"key": "enter"}} (keys: enter, space, escape, command, shift, etc.)
          * Use ONLY for shortcuts or control keys. For typing content, use paste_text.
        - delay: {"action": "delay", "params": {"duration": 1000}}
        - resubmit: {"action": "resubmit", "params": {"prompt": "Now click the search button..."}}
          * Use this if the task cannot be completed in one go (e.g., waiting for a page load, or needing to scroll and find something new). This will trigger a new screenshot and analysis cycle with the new prompt.
        - finish: {"action": "finish"} (Task completed)
        
        OUTPUT FORMAT:
        You MUST respond with a valid JSON object ONLY. No markdown blocks.
        {
            "thought": "I see the search bar. I will click it, paste the text, and press enter.",
            "tasks": [
                {"action": "move_mouse", "params": {"x": 0.5, "y": 0.5}},
                {"action": "click", "params": {"button": "left"}},
                {"action": "paste_text", "params": {"text": "Hello World"}},
                {"action": "key_press", "params": {"key": "enter"}},
                {"action": "finish", "params": null}
            ]
        }
        
        TIPS:
        1. Be precise with coordinates.
        2. If you need to double click, do: click -> delay 50ms -> click.
        3. If the task is complex, do the first part and use "resubmit" to continue.
        4. If the intent cannot be fulfilled on this screen, output "action": "fail".
        """
        
        let base64Image = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Intent: \(intent)"
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let payload: [String: Any] = [
            "model": SiliconFlowConfig.glmModel,
            "messages": messages,
            "temperature": 0.1, // 低温度保证稳定性
            "top_p": 0.1,
            "max_tokens": 2048,
            "enable_thinking": false // Explicitly disable thinking
            // "response_format": ["type": "json_object"] // GLM-4.6V 不支持 JSON 模式，已移除
        ]
        
        let responseContent = try await performSiliconFlowRequest(url: url, payload: payload)
        
        // 清理模型输出的 Markdown 标记和特殊的 box 标记
        var cleanContent = responseContent
        
        // 1. 移除 Markdown 代码块
        if cleanContent.contains("```json") {
            cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "```", with: "")
        } else if cleanContent.contains("```") {
            cleanContent = cleanContent.replacingOccurrences(of: "```", with: "")
        }
        
        // 2. 移除 <|begin_of_box|> 和 <|end_of_box|> (GLM-4V 特有)
        cleanContent = cleanContent.replacingOccurrences(of: "<|begin_of_box|>", with: "")
        cleanContent = cleanContent.replacingOccurrences(of: "<|end_of_box|>", with: "")
        
        guard let data = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw APIError.decodingFailed(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response content"]))
        }
        
        do {
            let result = try JSONDecoder().decode(VLMTaskResponse.self, from: data)
            return result
        } catch {
            print("[APIService] JSON Decode Error: \(error)")
            print("Raw Content: \(responseContent)")
            throw APIError.decodingFailed(error)
        }
    }
    
    /// 验证任务执行结果
    /// - Parameters:
    ///   - originalGoal: 原始任务目标
    ///   - imageData: 当前屏幕截图
    /// - Returns: ValidationResponse
    func validateTaskOutcome(originalGoal: String, imageData: Data) async throws -> ValidationResponse {
        let urlString = "https://api.siliconflow.cn/v1/chat/completions"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let systemPrompt = """
        You are a QA Validator for a macOS automation agent. Your job is to verify if the user's goal has been achieved based on the current screen.
        
        User Goal: "\(originalGoal)"
        
        OUTPUT FORMAT:
        You MUST respond with a valid JSON object ONLY.
        {
            "success": true | false,
            "summary": "Brief summary of what was achieved (if success) or what went wrong (if fail).",
            "nextPrompt": "If failed, provide a new precise prompt for the agent to retry/continue. If success, null."
        }
        
        CRITERIA:
        - If the goal is clearly met (e.g., "Open Safari" -> Safari window is visible), return success: true.
        - If the goal is partially met or completely failed, return success: false and a corrective nextPrompt.
        - Be strict but reasonable.
        """
        
        let base64Image = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let payload: [String: Any] = [
            "model": SiliconFlowConfig.glmModel,
            "messages": messages,
            "temperature": 0.1,
            "top_p": 0.1,
            "max_tokens": 1024,
            "enable_thinking": false
        ]
        
        let responseContent = try await performSiliconFlowRequest(url: url, payload: payload)
        
        // Clean JSON
        var cleanContent = responseContent
        if cleanContent.contains("```json") {
            cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "```", with: "")
        }
        cleanContent = cleanContent.replacingOccurrences(of: "<|begin_of_box|>", with: "")
        cleanContent = cleanContent.replacingOccurrences(of: "<|end_of_box|>", with: "")
        
        guard let data = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw APIError.decodingFailed(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty validation response"]))
        }
        
        do {
            return try JSONDecoder().decode(ValidationResponse.self, from: data)
        } catch {
            print("[APIService] Validation JSON Decode Error: \(error)")
            print("Raw Content: \(responseContent)")
            throw APIError.decodingFailed(error)
        }
    }
    
    private func performSiliconFlowRequest(url: URL, payload: [String: Any]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Increase timeout to 120 seconds
        
        let apiKey = SiliconFlowConfig.apiKey
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            print("[APIService] Warning: SILICONFLOW_API_KEY is missing!")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("[APIService] Sending request to \(payload["model"] ?? "unknown")...")
        
        // Debug: Print request body (truncated if too long for image data)
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            // Avoid printing massive base64 strings
            if bodyString.count > 2000 {
                print("[APIService] Request Body (Truncated): \(bodyString.prefix(1000))...")
            } else {
                print("[APIService] Request Body: \(bodyString)")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        
        struct SFResponse: Decodable {
            let choices: [Choice]
            struct Choice: Decodable {
                let message: Message
            }
            struct Message: Decodable {
                let content: String
            }
        }
        
        let sfResponse = try JSONDecoder().decode(SFResponse.self, from: data)
        return sfResponse.choices.first?.message.content ?? ""
    }
    
    // MARK: - Helper Methods
    
    private func postRequest(_ urlString: String, body: [String: Any]) async throws {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Increase timeout to 120 seconds for VLM tasks
        
        let httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = httpBody
        
        // 打印请求体以便调试
        if let bodyString = String(data: httpBody, encoding: .utf8) {
            print("[APIService] POST \(urlString) with body: \(bodyString)")
        } else {
            print("[APIService] POST \(urlString) with unknown body encoding")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        
        // 我们只关心是否成功发起，不需要解析具体的 response body，除非出错
        // 但为了调试，可以打印一下
        if let str = String(data: data, encoding: .utf8) {
            print("[APIService] Response from \(urlString): \(str)")
        }
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[APIService] Error \(httpResponse.statusCode): \(body)")
            throw APIError.serverError(httpResponse.statusCode, body)
        }
    }
}
