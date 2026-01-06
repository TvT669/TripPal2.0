//
//  BaseTool.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 工具基类 - 实现 Tool 协议的基础功能
class BaseTool: Tool {
    let name: String
    let description: String
    private let parameters: [String: ParameterDefinition]
    private let requiredParameters: [String]
    
    init(name: String,
         description: String,
         parameters: [String: ParameterDefinition] = [:],
         requiredParameters: [String] = []) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.requiredParameters = requiredParameters
    }
    
    // MARK: - Tool 协议实现
    
    func execute(arguments: [String: Any]) async throws -> ToolResult {
        // 1. 参数验证
        try validateArguments(arguments)
        
        // 2. 执行具体逻辑（由子类实现）
        return try await executeImpl(arguments: arguments)
    }
    
    func toParameters() -> [String: Any] {
        var properties: [String: [String: Any]] = [:]
        
        for (paramName, paramDef) in parameters {
            var property: [String: Any] = [
                "type": paramDef.type,
                "description": paramDef.description
            ]
            
            // ✅ 修复：只有当 enumValues 不为空时才添加 enum 字段
            if let enumValues = paramDef.enumValues, !enumValues.isEmpty {
                property["enum"] = enumValues
            }
            // ✅ 不要添加 "enum": null
            
            properties[paramName] = property
        }
        
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": requiredParameters
                ]
            ]
        ]
        
    }
        // MARK: - 子类需要实现的方法
        
        /// 具体的执行逻辑 - 子类必须重写
        func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
            fatalError("子类必须实现 executeImpl 方法")
        }
        
        // MARK: - 通用辅助方法
        
        func validateArguments(_ arguments: [String: Any]) throws {
            // 检查必需参数
            for required in requiredParameters {
                guard arguments[required] != nil else {
                    throw ToolError.missingRequiredParameter(required)
                }
            }
        }
        
        /// 获取字符串参数
        func getString(_ key: String, from arguments: [String: Any]) -> String? {
            return arguments[key] as? String
        }
        
        /// 获取数字参数
        func getNumber(_ key: String, from arguments: [String: Any]) -> Double? {
            if let number = arguments[key] as? NSNumber {
                return number.doubleValue
            }
            if let intValue = arguments[key] as? Int {
                return Double(intValue)
            }
            if let doubleValue = arguments[key] as? Double {
                return doubleValue
            }
            // 尝试从字符串转换
            if let stringValue = arguments[key] as? String, let doubleValue = Double(stringValue) {
                return doubleValue
            }
            return nil
        }
        
        /// 获取布尔参数
        func getBoolean(_ key: String, from arguments: [String: Any]) -> Bool? {
            if let boolValue = arguments[key] as? Bool {
                return boolValue
            }
            if let stringValue = arguments[key] as? String {
                return stringValue.lowercased() == "true"
            }
            return nil
        }
        
        /// 获取数组参数
        func getArray(_ key: String, from arguments: [String: Any]) -> [Any]? {
            return arguments[key] as? [Any]
        }
        
        /// 获取必需的字符串参数
        func getRequiredString(_ key: String, from arguments: [String: Any]) throws -> String {
            guard let value = getString(key, from: arguments) else {
                throw ToolError.missingRequiredParameter(key)
            }
            return value
        }
        
        /// 创建成功结果
        func successResult(_ output: String, metadata: [String: Any]? = nil) -> ToolResult {
            return ToolResult(output: output, metadata: metadata)
        }
        
        /// 创建错误结果
        func errorResult(_ error: String, metadata: [String: Any]? = nil) -> ToolResult {
            return ToolResult(error: error, metadata: metadata)
        }
    }
    
    // MARK: - 辅助数据结构
    
    /// 工具错误
    enum ToolError: Error, LocalizedError {
        case missingRequiredParameter(String)
        case executionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .missingRequiredParameter(let param):
                return "缺少必需参数: \(param)"
            case .executionFailed(let message):
                return "工具执行失败: \(message)"
            }
        }
    }

