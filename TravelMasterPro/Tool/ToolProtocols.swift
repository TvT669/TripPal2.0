//
//  ToolProtocols.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/23.
//

import Foundation

/// 工具执行结果
struct ToolResult {
    let output: String?
    let error: String?
    let base64Image: String?
    let metadata: [String: Any]?
    
    init(output: String? = nil, error: String? = nil, base64Image: String? = nil, metadata: [String: Any]? = nil) {
        self.output = output
        self.error = error
        self.base64Image = base64Image
        self.metadata = metadata
    }
    
    static func success(_ output: String, metadata: [String: Any]? = nil) -> ToolResult {
        return ToolResult(output: output, error: nil, metadata: metadata)
    }
    
    static func failure(_ error: String, metadata: [String: Any]? = nil) -> ToolResult {
        return ToolResult(output: nil, error: error, metadata: metadata)
    }
}

/// 参数定义
struct ParameterDefinition {
    let type: String
    let description: String
    let enumValues: [String]?
    
    init(type: String, description: String, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
    
    static func string(_ description: String, enumValues: [String]? = nil) -> ParameterDefinition {
        return ParameterDefinition(type: "string", description: description, enumValues: enumValues)
    }
    
    static func number(_ description: String) -> ParameterDefinition {
        return ParameterDefinition(type: "number", description: description, enumValues: nil)
    }
}

/// 工具协议
protocol Tool {
    var name: String { get }
    var description: String { get }
    
    func execute(arguments: [String: Any]) async throws -> ToolResult
    func toParameters() -> [String: Any]
}
