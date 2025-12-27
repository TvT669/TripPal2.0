//
//  FreehandDrawingView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/25.
//

import SwiftUI
import MapKit

struct FreehandDrawingView: View {
    @Binding var route: CustomRoute
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var drawnPoints: [CLLocationCoordinate2D] = []
    @State private var isDrawing: Bool = false
    
    var body: some View {
        ZStack {
            if #available(iOS 17.0, *) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        if !drawnPoints.isEmpty {
                            MapPolyline(coordinates: drawnPoints)
                                .stroke(.blue, lineWidth: 5)
                        }
                        UserAnnotation()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDrawing = true
                                // Convert screen point to map coordinate
                                if let coordinate = proxy.convert(value.location, from: .local) {
                                    addPoint(coordinate)
                                }
                            }
                            .onEnded { _ in
                                isDrawing = false
                                route.setPathCoordinates(drawnPoints)
                            }
                    )
                }
            } else {
                VStack {
                    Text("手绘功能需要 iOS 17 或更高版本")
                    Map(position: $cameraPosition) {
                         if !drawnPoints.isEmpty {
                            MapPolyline(coordinates: drawnPoints)
                                .stroke(.blue, lineWidth: 5)
                        }
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        drawnPoints.removeAll()
                        route.setPathCoordinates([])
                    }) {
                        Label("清除", systemImage: "trash")
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            drawnPoints = route.pathCoordinates
        }
    }
    
    private func addPoint(_ coordinate: CLLocationCoordinate2D) {
        if let last = drawnPoints.last {
            let loc1 = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let loc2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if loc1.distance(from: loc2) > 5 { // 5 meters filter
                drawnPoints.append(coordinate)
            }
        } else {
            drawnPoints.append(coordinate)
        }
    }
}
