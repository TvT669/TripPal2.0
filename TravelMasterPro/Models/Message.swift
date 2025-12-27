//
//  Message.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

// MARK: - 核心消息模型

/// 基础消息模型 - 简洁且灵活
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    // 可选的扩展属性
    var metadata: MessageMetadata?
    
    enum Role: String, Codable {
          case user = "user"
          case assistant = "assistant"
          case system = "system"
      }
    
    // MARK: - 初始化器
    
    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - 消息角色

enum MessageRole: String, Codable, CaseIterable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
    
    var displayName: String {
        switch self {
        case .system: return "系统"
        case .user: return "用户"
        case .assistant: return "助手"
        case .tool: return "工具"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear.circle"
        case .user: return "person.circle"
        case .assistant: return "brain.head.profile"
        case .tool: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - 消息元数据

/// 消息元数据 - 存储额外信息
struct MessageMetadata: Codable, Equatable {
    // 工具相关
    var toolCallId: String?
    var toolName: String?
    var toolArguments: [String: String]?
    
    // 媒体相关
    var attachments: [MessageAttachment]?
    
    // 智能体相关
    var agentType: String?
    var processingTime: TimeInterval?
    var confidence: Double?
    
    // 用户体验相关
    var isImportant: Bool?
    var tags: [String]?
    var quickActionId: String?
    
    init() {}
}

// MARK: - 消息附件

/// 消息附件 - 处理多媒体内容
struct MessageAttachment: Codable, Equatable, Identifiable {
    let id: String
    let type: AttachmentType
    let data: String // Base64 或 URL
    let filename: String?
    let mimeType: String?
    let size: Int?
    
    enum AttachmentType: String, Codable {
        case image = "image"
        case document = "document"
        case audio = "audio"
        case video = "video"
        case location = "location"
    }
    
    init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        data: String,
        filename: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
    }
}

// MARK: - 便利构造方法

extension Message {
    /// 创建用户消息
    static func userMessage(
        _ content: String,
        attachments: [MessageAttachment]? = nil,
        tags: [String]? = nil
    ) -> Message {
        var metadata: MessageMetadata? = nil
        if attachments != nil || tags != nil {
            metadata = MessageMetadata()
            metadata?.attachments = attachments
            metadata?.tags = tags
        }
        
        return Message(
            role: .user,
            content: content,
            metadata: metadata
        )
    }
    
    /// 创建助手消息
    static func assistantMessage(
        _ content: String,
        agentType: String? = nil,
        processingTime: TimeInterval? = nil,
        confidence: Double? = nil
    ) -> Message {
        var metadata: MessageMetadata? = nil
        if agentType != nil || processingTime != nil || confidence != nil {
            metadata = MessageMetadata()
            metadata?.agentType = agentType
            metadata?.processingTime = processingTime
            metadata?.confidence = confidence
        }
        
        return Message(
            role: .assistant,
            content: content,
            metadata: metadata
        )
    }
    
    /// 创建系统消息
    static func systemMessage(_ content: String) -> Message {
        return Message(
            role: .system,
            content: content
        )
    }
    
    /// 创建工具消息
    static func toolMessage(
        content: String,
        toolCallId: String,
        toolName: String,
        arguments: [String: String]? = nil
    ) -> Message {
        var metadata = MessageMetadata()
        metadata.toolCallId = toolCallId
        metadata.toolName = toolName
        metadata.toolArguments = arguments
        
        return Message(
            role: .tool,
            content: content,
            metadata: metadata
        )
    }
    
    /// 创建带图片的消息
    static func messageWithImage(
        role: MessageRole,
        content: String,
        imageData: String,
        filename: String? = nil
    ) -> Message {
        let imageAttachment = MessageAttachment(
            type: .image,
            data: imageData,
            filename: filename,
            mimeType: "image/jpeg"
        )
        
        var metadata = MessageMetadata()
        metadata.attachments = [imageAttachment]
        
        return Message(
            role: role,
            content: content,
            metadata: metadata
        )
    }
}

// MARK: - 消息扩展方法

extension Message {
    /// 是否包含附件
    var hasAttachments: Bool {
        return metadata?.attachments?.isEmpty == false
    }
    
    /// 获取图片附件
    var imageAttachments: [MessageAttachment] {
        return metadata?.attachments?.filter { $0.type == .image } ?? []
    }
    
    /// 是否为工具消息
    var isToolMessage: Bool {
        return role == .tool && metadata?.toolCallId != nil
    }
    
    /// 是否为重要消息
    var isImportant: Bool {
        return metadata?.isImportant == true
    }
    
    /// 获取标签
    var tags: [String] {
        return metadata?.tags ?? []
    }
    
    /// 获取处理时间
    var processingTime: TimeInterval? {
        return metadata?.processingTime
    }
    
    /// 获取智能体类型
    var agentType: String? {
        return metadata?.agentType
    }
    
    /// 标记为重要
    mutating func markAsImportant() {
        if metadata == nil {
            metadata = MessageMetadata()
        }
        metadata?.isImportant = true
    }
    
    /// 添加标签
    mutating func addTag(_ tag: String) {
        if metadata == nil {
            metadata = MessageMetadata()
        }
        if metadata?.tags == nil {
            metadata?.tags = []
        }
        metadata?.tags?.append(tag)
    }
    
    /// 添加附件
    mutating func addAttachment(_ attachment: MessageAttachment) {
        if metadata == nil {
            metadata = MessageMetadata()
        }
        if metadata?.attachments == nil {
            metadata?.attachments = []
        }
        metadata?.attachments?.append(attachment)
    }
}

// MARK: - 工具调用相关（保持不变）

/// 工具调用
struct ToolCall: Identifiable, Codable {
    let id: String
    let function: ToolFunction
    
    struct ToolFunction: Codable {
        let name: String
        let arguments: [String: String] // 简化为 String 类型
    }
}

/// 工具选择模式
enum ToolChoice: Codable {
    case none
    case auto
    case required
    case specific(String) // 指定特定工具
    
    var stringValue: String {
        switch self {
        case .none: return "none"
        case .auto: return "auto"
        case .required: return "required"
        case .specific(let toolName): return toolName
        }
    }
}

// MARK: - 智能体状态

/// 智能体状态
enum AgentState: Equatable {
    case idle
    case thinking
    case acting(String) // 包含当前操作描述
    case finished(String) // 包含结果摘要
    case error(String)
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .thinking: return "思考中"
        case .acting(let action): return "执行中: \(action)"
        case .finished(let summary): return "完成: \(summary)"
        case .error(let error): return "错误: \(error)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .thinking, .acting: return true
        default: return false
        }
    }
}

// MARK: - 消息统计

/// 消息统计信息
struct MessageStats {
    let totalCount: Int
    let userMessages: Int
    let assistantMessages: Int
    let systemMessages: Int
    let toolMessages: Int
    let averageLength: Double
    let totalProcessingTime: TimeInterval
    
    init(from messages: [Message]) {
        self.totalCount = messages.count
        self.userMessages = messages.filter { $0.role == .user }.count
        self.assistantMessages = messages.filter { $0.role == .assistant }.count
        self.systemMessages = messages.filter { $0.role == .system }.count
        self.toolMessages = messages.filter { $0.role == .tool }.count
        
        let totalLength = messages.reduce(0) { $0 + $1.content.count }
        self.averageLength = totalCount > 0 ? Double(totalLength) / Double(totalCount) : 0
        
        self.totalProcessingTime = messages.compactMap { $0.processingTime }.reduce(0, +)
    }
}
// 在 MessageMetadata 结构体中添加方便的初始化方法
extension MessageMetadata {
    /// 创建包含工具调用的元数据
    func with(toolCalls: [ToolCall]) -> MessageMetadata {
        var metadata = self
        metadata.toolCalls = toolCalls
        return metadata
    }
    
    /// 创建包含工具调用ID的元数据
    func with(toolCallId: String, toolName: String) -> MessageMetadata {
        var metadata = self
        metadata.toolCallId = toolCallId
        metadata.toolName = toolName
        return metadata
    }
}

// 在 MessageMetadata 中添加 toolCalls 属性
extension MessageMetadata {
    // ✅ 添加工具调用相关属性
    var toolCalls: [ToolCall]? {
        get {
            // 从现有的 toolName 和 toolArguments 构造 ToolCall
            if let name = toolName, let args = toolArguments {
                return [ToolCall(
                    id: toolCallId ?? UUID().uuidString,
                    function: ToolCall.ToolFunction(name: name, arguments: args)
                )]
            }
            return nil
        }
        set {
            if let toolCall = newValue?.first {
                toolCallId = toolCall.id
                toolName = toolCall.function.name
                toolArguments = toolCall.function.arguments
            }
        }
    }
}

