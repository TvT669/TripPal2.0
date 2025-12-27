//
//  MapUtilities.swift
//  NearMe
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/5/3.
//

import Foundation
import MapKit

func makeCall(phone: String) {
    // 1. 构造电话协议 URL（关键：正确的 URL Scheme 是 tel://）
    if let url = URL(string: "tel://\(phone)") {
        // 2. 检查设备是否支持拨打电话（如 iPad 可能不支持）
        if UIApplication.shared.canOpenURL(url) {
            // 3. 跳转到系统电话应用并自动拨号
            UIApplication.shared.open(url)
        } else {
            print("Device can't make phone calls")
        }
    }
}

func calculationDirections(from: MKMapItem, to: MKMapItem) async -> MKRoute? {
    // 1. 创建路线请求对象
    let directionsRequest = MKDirections.Request()
    
    // 2. 配置交通方式为汽车驾驶
    directionsRequest.transportType = .walking
    
    // 3. 设置起点和终点（使用MKMapItem的placemark坐标）
    directionsRequest.source = from       // 出发地
    directionsRequest.destination = to    // 目的地
    
    // 4. 创建路线计算器
    let directions = MKDirections(request: directionsRequest)
    
    // 5. 异步计算路线（使用try?忽略具体错误，静默返回nil）
    let response = try? await directions.calculate()
    
    // 6. 返回找到的第一条可行路线
    return response?.routes.first
}

func calculateDistance(from: CLLocation, to: CLLocation) -> Measurement<UnitLength> {
    let distanceInMeters = from.distance(from: to)
    return Measurement(value: distanceInMeters, unit: .meters)
}


func performSearch(searchTerm: String, visibleRegion: MKCoordinateRegion?) async throws -> [MKMapItem] {
    
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = searchTerm
    request.resultTypes = .pointOfInterest
    
    guard let region = visibleRegion else { return []}
    request.region = region
    
    let search = MKLocalSearch(request: request)
    let response = try await search.start()
    
    return response.mapItems
}
