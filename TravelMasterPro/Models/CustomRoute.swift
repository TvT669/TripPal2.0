import Foundation
import CoreLocation

struct CustomRoute: Identifiable, Codable {
    let id: UUID
    var title: String
    var isLoop: Bool
    var coordinatesData: Data? // Stores [TripNode.Coordinate] encoded
    var waypoints: [TripNode]
    var mode: RouteMode
    var createDate: Date
    
    enum RouteMode: String, Codable {
        case waypoint
        case freehand
    }
    
    init(id: UUID = UUID(), title: String, isLoop: Bool = false, coordinatesData: Data? = nil, waypoints: [TripNode] = [], mode: RouteMode = .waypoint, createDate: Date = Date()) {
        self.id = id
        self.title = title
        self.isLoop = isLoop
        self.coordinatesData = coordinatesData
        self.waypoints = waypoints
        self.mode = mode
        self.createDate = createDate
    }
    
    // Helper to get coordinates for freehand mode
    var pathCoordinates: [CLLocationCoordinate2D] {
        guard let data = coordinatesData else { return [] }
        if let decoded = try? JSONDecoder().decode([TripNode.Coordinate].self, from: data) {
            return decoded.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        return []
    }
    
    // Helper to set coordinates for freehand mode
    mutating func setPathCoordinates(_ coords: [CLLocationCoordinate2D]) {
        let codableCoords = coords.map { TripNode.Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        if let encoded = try? JSONEncoder().encode(codableCoords) {
            self.coordinatesData = encoded
        }
    }
}
