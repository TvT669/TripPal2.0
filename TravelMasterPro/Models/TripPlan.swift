//
//  TripPlan.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import Foundation
import CoreLocation

// 单个行程节点
struct TripNode: Identifiable, Codable {
    let id: UUID
    var name: String        // 地点名称
    var description: String // 简短描述/备注
    var startTime: Date?    // 建议游玩时间
    var day: Int?           // 所属天数 (Day 1, Day 2, etc.)
    var coordinate: Coordinate // 自定义坐标结构以支持 Codable
    var imageData: Data?    // 图片数据
    
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
    }
    
    var clCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    // 辅助初始化器
    init(id: UUID = UUID(), name: String, description: String, startTime: Date? = nil, day: Int? = nil, coordinate: Coordinate, imageData: Data? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.startTime = startTime
        self.day = day
        self.coordinate = coordinate
        self.imageData = imageData
    }
}

// 完整的行程单
struct TripPlan: Identifiable, Codable {
    let id: UUID
    var title: String
    var nodes: [TripNode]
    var createDate: Date
    
    init(id: UUID = UUID(), title: String, nodes: [TripNode], createDate: Date = Date()) {
        self.id = id
        self.title = title
        self.nodes = nodes
        self.createDate = createDate
    }
}
