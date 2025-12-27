//
//  LLmService.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

//
//  LLmService.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 高级 LLM 服务 - 智能体的语言大脑
/// 提供完整的大语言模型交互能力，包括工具调用、流式响应、错误重试等


class LLMService {
    var  apiKey: String
    private let baseURL: URL
    private let model: String
    private let urlSession: URLSession
    private let defaultConfig: LLMConfig
    
    // 服务监控
    private let serviceMonitor: LLMServiceMonitor
    
    // 重试配置
    private let retryConfig: RetryConfig
    
    init() {
        // 从 AIConfig.plist 加载配置
        guard let configPath = Bundle.main.path(forResource: "AIConfig", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath) as? [String: Any],
              let apiKey = config["API_KEY"] as? String,
              let baseURLString = config["BASE_URL"] as? String,
              let model = config["MODEL"] as? String else {
            fatalError("AIConfig.plist 配置错误")
        }
        
        self.apiKey = apiKey
        self.baseURL = URL(string: baseURLString)!
        self.model = model
        
        // 默认配置
        self.defaultConfig = LLMConfig(
            maxTokens: config["MAX_TOKENS"] as? Int ?? 4000,
            temperature: config["TEMPERATURE"] as? Double ?? 0.7,
            topP: config["TOP_P"] as? Double ?? 1.0,
            frequencyPenalty: config["FREQUENCY_PENALTY"] as? Double ?? 0.0,
            presencePenalty: config["PRESENCE_PENALTY"] as? Double ?? 0.0
        )
        
        // 重试配置
        self.retryConfig = RetryConfig(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0
        )
        
        // URL Session 配置
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 120
        sessionConfig.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: sessionConfig)
        
        // 服务监控
        self.serviceMonitor = LLMServiceMonitor()
    }
    
    // MARK: - 主要接口方法
    
    /// 标准对话 - 不使用工具
    func chat(
        messages: [Message],
        systemMessages: [Message]? = nil,
        config: LLMConfig? = nil
    ) async throws -> String {
        let result = try await askTool(
            messages: messages,
            systemMessages: systemMessages,
            tools: nil as [[String: Any]]?, // 明确类型
            toolChoice: LLMToolChoice.none, // 使用完整类型名
            config: config
        )
        
        return result.content ?? ""
    }
    
    /// 工具调用对话 - 支持工具使用
    func askTool(
        messages: [Message],
        systemMessages: [Message]? = nil,
        tools: [[String: Any]]? = nil,
        toolChoice: LLMToolChoice = .auto, // 使用重命名的枚举
        config: LLMConfig? = nil
    ) async throws -> LLMResponse {
        
        let startTime = Date()
        let requestConfig = config ?? defaultConfig
        
        do {
            let response = try await performRequestWithRetry { [weak self] in
                guard let self = self else { throw LLMError.serviceUnavailable }
                return try await self.performSingleRequest(
                    messages: messages,
                    systemMessages: systemMessages,
                    tools: tools,
                    toolChoice: toolChoice,
                    config: requestConfig
                )
            }
            
            // 记录成功请求
            let duration = Date().timeIntervalSince(startTime)
            serviceMonitor.recordRequest(
                success: true,
                duration: duration,
                tokenCount: response.usage?.totalTokens ?? 0,
                cost: calculateCost(usage: response.usage)
            )
            
            return response
            
        } catch {
            // 记录失败请求
            let duration = Date().timeIntervalSince(startTime)
            serviceMonitor.recordRequest(
                success: false,
                duration: duration,
                tokenCount: 0,
                cost: 0.0,
                error: error
            )
            throw error
        }
    }
    
    /// 流式对话 - 实时返回响应
    func streamChat(
        messages: [Message],
        systemMessages: [Message]? = nil,
        tools: [[String: Any]]? = nil,
        toolChoice: LLMToolChoice = .auto,
        config: LLMConfig? = nil,
        onChunk: @escaping (String) -> Void
    ) async throws -> LLMResponse {
        
        // 组合所有消息
        var allMessages = systemMessages ?? []
        allMessages.append(contentsOf: messages)
        
        let requestConfig = config ?? defaultConfig
        
        // 构建请求体
        var requestBody = buildRequestBody(
            messages: allMessages,
            tools: tools,
            toolChoice: toolChoice,
            config: requestConfig
        )
        requestBody["stream"] = true
        
        let url = baseURL.appendingPathComponent("/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        var fullContent = ""
        var toolCalls: [ToolCall] = []
        var usage: TokenUsage?
        
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" { break }
                
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any] {
                    
                    // 处理内容流
                    if let content = delta["content"] as? String {
                        fullContent += content
                        onChunk(content)
                    }
                    
                    // 处理工具调用
                    if let toolCallsData = delta["tool_calls"] as? [[String: Any]] {
                        // 处理工具调用增量更新
                        for toolCallData in toolCallsData {
                            // 这里简化处理，实际需要处理增量更新
                            if let id = toolCallData["id"] as? String,
                               let function = toolCallData["function"] as? [String: Any],
                               let name = function["name"] as? String,
                               let arguments = function["arguments"] as? String {
                                // 构建完整的工具调用
                            }
                        }
                    }
                }
                
                // 提取使用统计
                if let usageData = (try? JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!)) as? [String: Any],
                   let usageInfo = usageData["usage"] as? [String: Any] {
                    usage = parseTokenUsage(usageInfo)
                }
            }
        }
        
        return LLMResponse(
            content: fullContent.isEmpty ? nil : fullContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            usage: usage
        )
    }

    func completion(messages: [Message]) async throws -> String {
    return try await chat(messages: messages)
}
     func updateApiKey(_ newApiKey: String) {
    self.apiKey = newApiKey
}
     func reconnect() async throws {
        // 简单的连接测试
        let testMessage = Message(role: .user, content: "ping")
        _ = try await completion(messages: [testMessage])
    }


    
    // MARK: - 核心请求方法
    
    private func performSingleRequest(
        messages: [Message],
        systemMessages: [Message]?,
        tools: [[String: Any]]?,
        toolChoice: LLMToolChoice,
        config: LLMConfig
    ) async throws -> LLMResponse {
        
        // 组合所有消息
        var allMessages = systemMessages ?? []
        allMessages.append(contentsOf: messages)
        
        // 构建请求体
        let requestBody = buildRequestBody(
            messages: allMessages,
            tools: tools,
            toolChoice: toolChoice,
            config: config
        )
        
        // 发送请求
        let data = try await sendRequest(endpoint: "/chat/completions", body: requestBody)
        
        // 解析响应
        return try parseResponse(data)
    }
    
    private func buildRequestBody(
        messages: [Message],
        tools: [[String: Any]]?,
        toolChoice: LLMToolChoice,
        config: LLMConfig
    ) -> [String: Any] {
        
        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { formatMessage($0) },
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "top_p": config.topP,
            "frequency_penalty": config.frequencyPenalty,
            "presence_penalty": config.presencePenalty
        ]
        
        if baseURL.absoluteString.contains("deepseek") {
              // DeepSeek 可能不支持某些参数
              // 只保留基本参数
          } else {
              // OpenAI 格式的完整参数
              requestBody["top_p"] = config.topP
              requestBody["frequency_penalty"] = config.frequencyPenalty
              requestBody["presence_penalty"] = config.presencePenalty
          }
        
        // 添加工具配置
        if let tools = tools {
            requestBody["tools"] = tools
            
            switch toolChoice {
            case .auto:
                requestBody["tool_choice"] = "auto"
            case .required:
                requestBody["tool_choice"] = "required"
            case .none:
                requestBody["tool_choice"] = "none"
            case .specific(let toolName):
                requestBody["tool_choice"] = [
                    "type": "function",
                    "function": ["name": toolName]
                ]
            }
        }
        
        return requestBody
    }
    
    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        // 检查错误
        if let error = responseDict["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw LLMError.apiError(message)
        }
        
        guard let choices = responseDict["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        // 提取内容和工具调用
        let content = message["content"] as? String
        let toolCallsData = message["tool_calls"] as? [[String: Any]]
        
        // 解析工具调用
        var toolCalls: [ToolCall]?
        if let toolCallsData = toolCallsData, !toolCallsData.isEmpty {
            toolCalls = try toolCallsData.map { callData in
                guard let id = callData["id"] as? String,
                      let function = callData["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let argumentsString = function["arguments"] as? String else {
                    throw LLMError.invalidToolCall
                }
                
                let arguments: [String: String]
                if let argsData = argumentsString.data(using: .utf8),
                   let parsedArgs = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                       arguments = parsedArgs.compactMapValues { value in
                                       if let stringValue = value as? String {
                                           return stringValue
                                       } else if let numberValue = value as? NSNumber {
                                           return numberValue.stringValue
                                       } else {
                                           return String(describing: value)
                                       }
                                   }
                } else {
                    arguments = [:]
                }
                
                return ToolCall(
                    id: id,
                    function: ToolCall.ToolFunction(
                        name: name,
                        arguments: arguments
                    )
                )
            }
        }
        
        // 解析使用统计
        let usage = responseDict["usage"] as? [String: Any]
        let tokenUsage = usage != nil ? parseTokenUsage(usage!) : nil
        
        return LLMResponse(
            content: content,
            toolCalls: toolCalls,
            usage: tokenUsage
        )
    }
    
    private func parseTokenUsage(_ usageData: [String: Any]) -> TokenUsage {
        return TokenUsage(
            promptTokens: usageData["prompt_tokens"] as? Int ?? 0,
            completionTokens: usageData["completion_tokens"] as? Int ?? 0,
            totalTokens: usageData["total_tokens"] as? Int ?? 0
        )
    }
    
    // MARK: - 重试机制
    
    private func performRequestWithRetry<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        
        var lastError: Error?
        
        for attempt in 0...retryConfig.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // 检查是否应该重试
                if !shouldRetry(error: error, attempt: attempt) {
                    throw error
                }
                
                // 计算延迟时间
                let delay = calculateRetryDelay(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? LLMError.maxRetriesExceeded
    }
    
    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < retryConfig.maxRetries else { return false }
        
        // 根据错误类型决定是否重试
        if let llmError = error as? LLMError {
            switch llmError {
            case .networkError, .timeout, .serviceUnavailable:
                return true
            case .httpError(let code):
                return code >= 500 || code == 429 // 服务器错误或限流
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func calculateRetryDelay(attempt: Int) -> Double {
        let exponentialDelay = retryConfig.baseDelay * pow(retryConfig.backoffMultiplier, Double(attempt))
        let jitter = Double.random(in: 0.8...1.2) // 添加抖动
        return min(exponentialDelay * jitter, retryConfig.maxDelay)
    }
    
    // MARK: - 辅助方法
    
    private func sendRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = requestData
        
        // ✅ 添加调试日志
        print("🔍 请求 URL: \(url)")
        print("🔍 请求头: \(request.allHTTPHeaderFields ?? [:])")
        print("🔍 请求体: \(String(data: requestData, encoding: .utf8) ?? "无法解析")")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            // ✅ 添加响应日志
            print("🔍 响应状态码: \(httpResponse.statusCode)")
            print("🔍 响应头: \(httpResponse.allHeaderFields)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ 错误响应体: \(errorMessage)")
                throw LLMError.httpError(httpResponse.statusCode)
            }
            
            print("✅ 成功响应: \(String(data: data, encoding: .utf8)?.prefix(200) ?? "无法解析")")
            return data
            
        } catch {
            print("❌ 网络请求失败: \(error)")
            if error is URLError {
                throw LLMError.networkError
            }
            throw error
        }
    }
    
    private func formatMessage(_ message: Message) -> [String: Any] {
        var formattedMessage: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content
        ]
        
        // ✅ 处理 assistant 消息中的工具调用
        if message.role == .assistant,
           let metadata = message.metadata,
           let toolCalls = metadata.toolCalls {
            
            let formattedToolCalls = toolCalls.map { toolCall in
                return [
                    "id": toolCall.id,
                    "type": "function",
                    "function": [
                        "name": toolCall.function.name,
                        "arguments": convertArgumentsToJSON(toolCall.function.arguments)
                    ]
                ]
            }
            formattedMessage["tool_calls"] = formattedToolCalls
        }
        
        // ✅ 处理 tool 消息
        if message.role == .tool {
            if let toolCallId = message.metadata?.toolCallId {
                formattedMessage["tool_call_id"] = toolCallId
            }
            if let toolName = message.metadata?.toolName {
                formattedMessage["name"] = toolName
            }
        }
        
        // 处理图片附件
        if let attachments = message.metadata?.attachments,
           !attachments.isEmpty {
            let imageAttachments = attachments.filter { $0.type == .image }
            if !imageAttachments.isEmpty {
                var contentArray: [[String: Any]] = [
                    ["type": "text", "text": message.content]
                ]
                
                for attachment in imageAttachments {
                    contentArray.append([
                        "type": "image_url",
                        "image_url": [
                            "url": "data:\(attachment.mimeType ?? "image/jpeg");base64,\(attachment.data)"
                        ]
                    ])
                }
                formattedMessage["content"] = contentArray
            }
        }
        
        return formattedMessage
    }

    // ✅ 添加参数转换方法
    private func convertArgumentsToJSON(_ arguments: [String: String]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: arguments)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    private func calculateCost(usage: TokenUsage?) -> Double {
        guard let usage = usage else { return 0.0 }
        
        // 这里根据实际的模型定价计算成本
        // 以 GPT-4 为例的简化计算
        let inputCostPer1K = 0.03  // $0.03 per 1K tokens
        let outputCostPer1K = 0.06 // $0.06 per 1K tokens
        
        let inputCost = Double(usage.promptTokens) / 1000.0 * inputCostPer1K
        let outputCost = Double(usage.completionTokens) / 1000.0 * outputCostPer1K
        
        return inputCost + outputCost
    }
    
    // MARK: - 服务状态
    
    func getServiceStatus() -> LLMServiceStatus {
        return serviceMonitor.getStatus()
    }
    
    func resetStatistics() {
        serviceMonitor.reset()
    }
}

// MARK: - 配置和数据模型

/// LLM 配置
struct LLMConfig {
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let frequencyPenalty: Double
    let presencePenalty: Double
    
    static let `default` = LLMConfig(
        maxTokens: 4000,
        temperature: 0.7,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0
    )
    
    static let creative = LLMConfig(
        maxTokens: 4000,
        temperature: 1.0,
        topP: 0.9,
        frequencyPenalty: 0.1,
        presencePenalty: 0.1
    )
    
    static let precise = LLMConfig(
        maxTokens: 4000,
        temperature: 0.1,
        topP: 0.95,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0
    )
}

/// 重试配置
struct RetryConfig {
    let maxRetries: Int
    let baseDelay: Double
    let maxDelay: Double
    let backoffMultiplier: Double
}

/// LLM 响应
struct LLMResponse {
    let content: String?
    let toolCalls: [ToolCall]?
    let usage: TokenUsage?
}

/// Token 使用统计
struct TokenUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// LLM 专用的工具选择枚举 (重命名避免冲突)
enum LLMToolChoice {
    case auto
    case required
    case none
    case specific(String)
}

/// LLM 错误类型
enum LLMError: Error, LocalizedError {
    case networkError
    case timeout
    case serviceUnavailable
    case httpError(Int)
    case apiError(String)
    case invalidResponse
    case invalidToolCall
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "网络连接错误"
        case .timeout:
            return "请求超时"
        case .serviceUnavailable:
            return "服务不可用"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .apiError(let message):
            return "API错误: \(message)"
        case .invalidResponse:
            return "无效响应"
        case .invalidToolCall:
            return "无效工具调用"
        case .maxRetriesExceeded:
            return "超过最大重试次数"
        }
    }
}

// MARK: - 服务监控

/// LLM 服务监控器
class LLMServiceMonitor {
    private var requestCount: Int = 0
    private var successCount: Int = 0
    private var totalDuration: TimeInterval = 0
    private var totalTokens: Int = 0
    private var totalCost: Double = 0
    private var lastErrors: [Error] = []
    private let maxErrorHistory = 10
    
    private let queue = DispatchQueue(label: "llm.monitor", attributes: .concurrent)
    
    func recordRequest(
        success: Bool,
        duration: TimeInterval,
        tokenCount: Int,
        cost: Double,
        error: Error? = nil
    ) {
        queue.async(flags: .barrier) {
            self.requestCount += 1
            self.totalDuration += duration
            self.totalTokens += tokenCount
            self.totalCost += cost
            
            if success {
                self.successCount += 1
            } else if let error = error {
                self.lastErrors.append(error)
                if self.lastErrors.count > self.maxErrorHistory {
                    self.lastErrors.removeFirst()
                }
            }
        }
    }
    
    func getStatus() -> LLMServiceStatus {
        return queue.sync {
            return LLMServiceStatus(
                requestCount: requestCount,
                successRate: requestCount > 0 ? Double(successCount) / Double(requestCount) : 0,
                averageResponseTime: requestCount > 0 ? totalDuration / Double(requestCount) : 0,
                totalTokens: totalTokens,
                totalCost: totalCost,
                recentErrors: Array(lastErrors.suffix(5))
            )
        }
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self.requestCount = 0
            self.successCount = 0
            self.totalDuration = 0
            self.totalTokens = 0
            self.totalCost = 0
            self.lastErrors.removeAll()
        }
    }
}

/// LLM 服务状态
struct LLMServiceStatus {
    let requestCount: Int
    let successRate: Double
    let averageResponseTime: TimeInterval
    let totalTokens: Int
    let totalCost: Double
    let recentErrors: [Error]
    
    var formattedStatus: String {
        return """
        📊 LLM服务状态：
        • 请求次数：\(requestCount)
        • 成功率：\(String(format: "%.1f%%", successRate * 100))
        • 平均响应时间：\(String(format: "%.2fs", averageResponseTime))
        • 总Token数：\(totalTokens)
        • 总成本：$\(String(format: "%.4f", totalCost))
        • 最近错误：\(recentErrors.count)个
        """
    }
}


extension LLMService {
    
    /// 智能工具调用 - 处理完整的工具调用流程
    func thinkAndAct(
        messages: [Message],
        availableTools: [Tool],
        config: LLMConfig? = nil
    ) async throws -> LLMResponse {
        
        var conversationMessages = messages
        var iterationCount = 0
        let maxIterations = 5
        let requestConfig = config ?? defaultConfig
        
        while iterationCount < maxIterations {
            iterationCount += 1
            print("🔄 工具调用迭代 \(iterationCount)")
            
            // 准备工具参数
            let toolParameters = availableTools.map { $0.toParameters() }
            
            // 验证消息序列
            try validateMessageSequence(conversationMessages)
            
            // 发送请求（包含工具）
            let response = try await askTool(
                messages: conversationMessages,
                tools: toolParameters.isEmpty ? nil : toolParameters,
                toolChoice: toolParameters.isEmpty ? .none : .auto,
                config: requestConfig
            )
            
            // 检查是否有工具调用
            guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else {
                // 没有工具调用，直接返回响应
                return response
            }
            
            // ✅ 关键修复：添加 assistant 消息（包含工具调用）
            // 注意：当有工具调用时，不保存文本内容（避免显示 DSML 标记）
            let assistantMessage = Message(
                id: UUID().uuidString,
                role: .assistant,
                content: "", // 工具调用时使用空字符串,避免显示 DSML
                metadata: MessageMetadata().with(toolCalls: toolCalls)
            )
            conversationMessages.append(assistantMessage)
            
            // 执行工具调用并添加 tool 消息
            var allToolResults: [String] = []
            
            for toolCall in toolCalls {
                do {
                    print("🔧 执行工具: \(toolCall.function.name)")
                    let toolResult = try await executeToolCall(toolCall, tools: availableTools)
                    
                    // ✅ 为每个工具调用添加单独的 tool 消息
                    let toolMessage = Message(
                        id: UUID().uuidString,
                        role: .tool,
                        content: toolResult.output ?? toolResult.error ?? "工具执行完成",
                        metadata: MessageMetadata().with(
                            toolCallId: toolCall.id,
                            toolName: toolCall.function.name
                        )
                    )
                    conversationMessages.append(toolMessage)
                    
                    // 收集结果
                    if let output = toolResult.output {
                        allToolResults.append("【\(toolCall.function.name)】\n\(output)")
                    } else if let error = toolResult.error {
                        allToolResults.append("【\(toolCall.function.name) 错误】\n\(error)")
                    }
                    
                } catch {
                    print("❌ 工具执行失败: \(error)")
                    
                    // 即使工具执行失败，也要添加 tool 消息
                    let errorMessage = Message(
                        id: UUID().uuidString,
                        role: .tool,
                        content: "工具执行失败: \(error.localizedDescription)",
                        metadata: MessageMetadata().with(
                            toolCallId: toolCall.id,
                            toolName: toolCall.function.name
                        )
                    )
                    conversationMessages.append(errorMessage)
                    
                    allToolResults.append("【\(toolCall.function.name) 错误】\n工具执行失败: \(error.localizedDescription)")
                }
            }
            
            // 发送最终请求获取总结响应（不包含工具）
            let finalResponse = try await askTool(
                messages: conversationMessages,
                tools: nil,
                toolChoice: .none,
                config: requestConfig
            )
            
            // 返回包含工具结果的最终响应
            return LLMResponse(
                content: finalResponse.content ?? allToolResults.joined(separator: "\n\n"),
                toolCalls: nil,
                usage: finalResponse.usage
            )
        }
        
        throw LLMError.maxRetriesExceeded
    }
    
    /// 执行单个工具调用
    private func executeToolCall(_ toolCall: ToolCall, tools: [Tool]) async throws -> ToolResult {
        // 找到对应的工具
        guard let tool = tools.first(where: { $0.name == toolCall.function.name }) else {
            throw LLMError.apiError("未找到工具: \(toolCall.function.name)")
        }
        
        // 转换参数格式
        let arguments = toolCall.function.arguments.reduce(into: [String: Any]()) { result, pair in
            result[pair.key] = pair.value
        }
        
        // 执行工具
        return try await tool.execute(arguments: arguments)
    }
    
    /// 验证消息序列
    private func validateMessageSequence(_ messages: [Message]) throws {
        for i in 0..<messages.count {
            let message = messages[i]
            
            if message.role == .tool {
                // tool 消息必须跟在包含 tool_calls 的 assistant 消息后面
                guard i > 0 else {
                    throw LLMError.apiError("tool 消息不能是第一条消息")
                }
                
                let previousMessage = messages[i - 1]
                guard previousMessage.role == .assistant else {
                    throw LLMError.apiError("tool 消息必须跟在 assistant 消息后面")
                }
                
                // 验证 tool_call_id 存在
                guard message.metadata?.toolCallId != nil else {
                    throw LLMError.apiError("tool 消息必须包含 tool_call_id")
                }
            }
        }
    }
}


