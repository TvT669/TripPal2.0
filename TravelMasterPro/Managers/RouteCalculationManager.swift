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
}
