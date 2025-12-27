//
//  ParsedPlace.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import Foundation

// 用于解析预览的临时结构
struct ParsedPlace: Identifiable, Codable {
    let id: UUID
    var name: String
    var originalText: String // 原文片段，方便用户对照
    var isSelected: Bool     // 用户是否勾选
    var day: Int?            // AI识别的天数
    var coordinate: TripNode.Coordinate? // 可能还没查到坐标
    
    init(id: UUID = UUID(), name: String, originalText: String, isSelected: Bool = true, day: Int? = nil, coordinate: TripNode.Coordinate? = nil) {
        self.id = id
        self.name = name
        self.originalText = originalText
        self.isSelected = isSelected
        self.day = day
        self.coordinate = coordinate
    }
}
