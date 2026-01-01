//
//  VLMModels.swift
//  SkillFlow
//
//  Created by SkillFlow Automation on 2026/1/1.
//

import Foundation
import CoreGraphics

// MARK: - VLM Action Models

struct VLMAction: Codable {
    /// 模型的思考过程，解释为什么选择这个动作
    let thought: String
    /// 执行的具体动作类型
    let action: VLMActionType
    /// 动作的参数
    let params: ActionParams?
    
    enum CodingKeys: String, CodingKey {
        case thought, action, params
    }
}

enum VLMActionType: String, Codable {
    case click          // 单击
    case doubleClick    // 双击
    case rightClick     // 右键点击
    case type           // 输入文本
    case scroll         // 滚动
    case drag           // 拖拽
    case wait           // 等待
    case finish         // 任务完成
    case fail           // 任务失败
}

struct ActionParams: Codable {
    /// 归一化的 X 坐标 (0.0 - 1.0)
    let x: Double?
    /// 归一化的 Y 坐标 (0.0 - 1.0)
    let y: Double?
    /// 要输入的文本内容
    let text: String?
    /// 持续时间（秒）或滚动距离
    let duration: Double?
    /// 滚动方向或辅助参数
    let direction: String?
}

// MARK: - Vision Analysis Models

struct OCRResult: Codable {
    /// 识别到的文本
    let text: String
    /// 文本在图像中的归一化矩形区域 (Vision 坐标系: 原点在左下)
    let normalizedRect: CGRect
    /// 识别置信度
    let confidence: Float
    
    enum CodingKeys: String, CodingKey {
        case text, normalizedRect, confidence
    }
    
    // 自定义编码以简化 JSON 输出给 VLM
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        // 将 CGRect 编码为数组 [x, y, w, h] 节省 token
        let rectArray = [normalizedRect.origin.x, normalizedRect.origin.y, normalizedRect.size.width, normalizedRect.size.height]
        try container.encode(rectArray, forKey: .normalizedRect)
        try container.encode(confidence, forKey: .confidence)
    }
    
    init(text: String, normalizedRect: CGRect, confidence: Float) {
        self.text = text
        self.normalizedRect = normalizedRect
        self.confidence = confidence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Float.self, forKey: .confidence)
        
        let rectArray = try container.decode([Double].self, forKey: .normalizedRect)
        if rectArray.count == 4 {
            normalizedRect = CGRect(x: rectArray[0], y: rectArray[1], width: rectArray[2], height: rectArray[3])
        } else {
            normalizedRect = .zero
        }
    }
}
