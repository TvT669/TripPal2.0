import Foundation
import MapKit
import CoreLocation

class RouteCalculationManager {
    static let shared = RouteCalculationManager()
    
    private init() {}
    
    // Calculate route for a sequence of nodes
    func calculateRoute(for nodes: [TripNode], isLoop: Bool = false) async -> [MKRoute] {
        guard nodes.count >= 2 else { return [] }
        
        var routes: [MKRoute] = []
        var segments: [(TripNode, TripNode)] = []
        
        // Create segments A->B, B->C
        for i in 0..<(nodes.count - 1) {
            segments.append((nodes[i], nodes[i+1]))
        }
        
        // Add loop segment C->A if needed
        if isLoop, let first = nodes.first, let last = nodes.last {
            segments.append((last, first))
        }
        
        // Calculate each segment
        for segment in segments {
            if let route = await calculateSegment(from: segment.0, to: segment.1) {
                routes.append(route)
            }
        }
        
        return routes
    }
    
    private func calculateSegment(from: TripNode, to: TripNode) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.clCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.clCoordinate))
        request.transportType = .walking // Default to walking as per requirement
        
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            return response.routes.first
        } catch {
            // 如果步行路线失败（例如跨海、距离过远），尝试使用汽车路线作为后备
            if let mkError = error as? MKError, mkError.code == .directionsNotFound || mkError.code.rawValue == 2 { // 2 is often "Directions Not Available"
                 print("Walking route failed, trying automobile: \(error.localizedDescription)")
                 request.transportType = .automobile
                 let retryDirections = MKDirections(request: request)
                 do {
                     let retryResponse = try await retryDirections.calculate()
                     return retryResponse.routes.first
                 } catch {
                     print("Automobile route also failed: \(error)")
                     return nil
                 }
            }
            
            print("Error calculating route segment: \(error)")
            return nil
        }
    }
    
    // MARK: - TSP Optimization
    
    /// TSP 优化：使用最近邻居法 (Nearest Neighbor) 对景点进行重新排序
    /// - Parameters:
    ///   - nodes: 待排序的景点列表
    ///   - fixedStart: 是否固定第一个点作为起始点（默认为 true）
    /// - Returns: 优化后的有序列表
    func optimizeRoute(nodes: [TripNode], fixedStart: Bool = true) -> [TripNode] {
        guard nodes.count > 2 else { return nodes }
        
        var unvisited = nodes
        var optimized: [TripNode] = []
        
        // 1. 确定起始点
        if fixedStart {
            let start = unvisited.removeFirst()
            optimized.append(start)
        } else {
            // 如果不固定起点，这里简单取第一个
            let start = unvisited.removeFirst()
            optimized.append(start)
        }
        
        var current = optimized.last!
        
        // 2. 贪心查找最近邻居
        while !unvisited.isEmpty {
            if let (index, nearest) = findNearest(from: current, in: unvisited) {
                optimized.append(nearest)
                current = nearest
                unvisited.remove(at: index)
            } else {
                break
            }
        }
        
        return optimized
    }
    
    private func findNearest(from current: TripNode, in candidates: [TripNode]) -> (Int, TripNode)? {
        guard !candidates.isEmpty else { return nil }
        
        let startLoc = CLLocation(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude)
        
        var bestIndex = -1
        var minDest: CLLocationDistance = .greatestFiniteMagnitude
        
        for (i, candidate) in candidates.enumerated() {
            let endLoc = CLLocation(latitude: candidate.coordinate.latitude, longitude: candidate.coordinate.longitude)
            let dist = startLoc.distance(from: endLoc)
            
            if dist < minDest {
                minDest = dist
                bestIndex = i
            }
        }
        
        if bestIndex >= 0 {
            return (bestIndex, candidates[bestIndex])
        }
        return nil
    }
}
