//
//  TripDetailView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import SwiftUI
import MapKit

struct TripDetailView: View {
    let plan: TripPlan
    @State private var region: MKCoordinateRegion
    @State private var selectedDay: Int? = nil // nil 表示"全部"
    
    init(plan: TripPlan) {
        self.plan = plan
        
        // 初始化地图区域
        if let first = plan.nodes.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: first.clCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }
    
    // 计算属性：过滤后的节点（只包含有效坐标的节点）
    var filteredNodes: [TripNode] {
        let nodes: [TripNode]
        if let day = selectedDay {
            nodes = plan.nodes.filter { $0.day == day }
        } else {
            nodes = plan.nodes
        }
        // 过滤掉坐标为 (0, 0) 的无效节点
        return nodes.filter { node in
            let coord = node.coordinate
            return coord.latitude != 0 || coord.longitude != 0
        }
    }
    
    // 根据天数返回颜色
    var dayColor: Color {
        guard let day = selectedDay else { return .chiikawaBlue }
        let colors: [Color] = [.chiikawaBlue, .chiikawaPink, .chiikawaYellow, .purple, .orange, .green]
        return colors[(day - 1) % colors.count]
    }
    
    // 计算总天数
    var totalDays: Int {
        let days = plan.nodes.compactMap { $0.day }
        return days.isEmpty ? 0 : (days.max() ?? 0)
    }
    
    // 生成路径线坐标
    var routeCoordinates: [CLLocationCoordinate2D] {
        return filteredNodes.map { $0.clCoordinate }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 上半部分：地图轨迹（使用自定义地图视图）
            TripMapView(
                nodes: filteredNodes,
                selectedDay: selectedDay,
                region: $region
            )
            .frame(height: 250)
            .cornerRadius(20, corners: [.bottomLeft, .bottomRight]) // 底部圆角
            .shadow(color: .chiikawaText.opacity(0.1), radius: 5, x: 0, y: 5)
            .onChange(of: selectedDay) { _ in
                updateMapRegion()
            }
            
            // 分日切换器
            if totalDays > 0 {
                DaySelectorView(selectedDay: $selectedDay, totalDays: totalDays)
                    .padding(.top, 8)
            }
            
            // 下半部分：卡片列表
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(plan.title)
                        .chiikawaFont(.title2, weight: .bold)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ForEach(Array(plan.nodes.filter { node in
                        if let day = selectedDay {
                            return node.day == day
                        }
                        return true
                    }.enumerated()), id: \.element.id) { index, node in
                        TripCardView(node: node, isLast: false)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color.chiikawaWhite) // 背景色
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.chiikawaWhite)
    }
    
    // 更新地图区域以适应当前显示的节点
    private func updateMapRegion() {
        guard !filteredNodes.isEmpty else { return }
        
        let coordinates = filteredNodes.map { $0.clCoordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.5,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.5
        )
        
        withAnimation {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

// MARK: - Trip Map View with Route
struct TripMapView: UIViewRepresentable {
    let nodes: [TripNode]
    let selectedDay: Int?
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 清除现有的覆盖层和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // 更新地图区域
        mapView.setRegion(region, animated: true)
        
        // 添加标注点
        for (index, node) in nodes.enumerated() {
            let annotation = TripAnnotation(
                coordinate: node.clCoordinate,
                title: node.name,
                index: index + 1,
                day: node.day // 使用节点自身的天数，以便在"全部"视图中显示不同颜色
            )
            mapView.addAnnotation(annotation)
        }
        
        // 绘制路径
        if let day = selectedDay {
            // 单日视图：绘制一条线
            if nodes.count >= 2 {
                let coordinates = nodes.map { $0.clCoordinate }
                let polyline = TripPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.day = day
                mapView.addOverlay(polyline)
            }
        } else {
            // 全部视图：按天分组绘制多条线
            // 获取所有涉及的天数
            let days = Set(nodes.compactMap { $0.day }).sorted()
            
            for day in days {
                // 获取该天的所有节点，并保持原始顺序
                let dayNodes = nodes.filter { $0.day == day }
                
                if dayNodes.count >= 2 {
                    let coordinates = dayNodes.map { $0.clCoordinate }
                    let polyline = TripPolyline(coordinates: coordinates, count: coordinates.count)
                    polyline.day = day
                    mapView.addOverlay(polyline)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDay: selectedDay)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let selectedDay: Int?
        
        init(selectedDay: Int?) {
            self.selectedDay = selectedDay
        }
        
        // 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let tripAnnotation = annotation as? TripAnnotation else { return nil }
            
            let identifier = "TripMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 创建自定义标记图像
            let markerColor = dayColor(for: tripAnnotation.day)
            let markerImage = createMarkerImage(index: tripAnnotation.index, color: markerColor)
            annotationView?.image = markerImage
            annotationView?.centerOffset = CGPoint(x: 0, y: -16)
            
            return annotationView
        }
        
        // 自定义路径样式
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // 如果是 TripPolyline，使用其指定的颜色
                if let tripPolyline = polyline as? TripPolyline, let day = tripPolyline.day {
                    renderer.strokeColor = dayColor(for: day)
                } else {
                    renderer.strokeColor = dayColor(for: selectedDay)
                }
                
                renderer.lineWidth = 4
                renderer.lineDashPattern = [10, 5]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        private func dayColor(for day: Int?) -> UIColor {
            guard let day = day else { return .systemBlue }
            let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemRed]
            return colors[(day - 1) % colors.count]
        }
        
        private func createMarkerImage(index: Int, color: UIColor) -> UIImage {
            let size = CGSize(width: 32, height: 32)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                // 绘制圆形背景
                color.setFill()
                let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                circle.fill()
                
                // 添加阴影效果
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 3, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                
                // 绘制数字
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.white
                ]
                let text = "\(index)"
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}

// MARK: - Trip Annotation
class TripAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let index: Int
    let day: Int?
    
    init(coordinate: CLLocationCoordinate2D, title: String, index: Int, day: Int?) {
        self.coordinate = coordinate
        self.title = title
        self.index = index
        self.day = day
    }
}

// MARK: - Trip Polyline
class TripPolyline: MKPolyline {
    var day: Int?
}

// MARK: - Day Selector View
struct DaySelectorView: View {
    @Binding var selectedDay: Int?
    let totalDays: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                DayButton(title: "全部", isSelected: selectedDay == nil, color: .chiikawaBlue) {
                    withAnimation {
                        selectedDay = nil
                    }
                }
                
                // Day 1, Day 2, ...
                ForEach(1...totalDays, id: \.self) { day in
                    let color: Color = [.chiikawaBlue, .chiikawaPink, .chiikawaYellow, .purple, .orange, .green][(day - 1) % 6]
                    DayButton(title: "Day \(day)", isSelected: selectedDay == day, color: color) {
                        withAnimation {
                            selectedDay = day
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.chiikawaWhite)
    }
}

struct DayButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .chiikawaFont(.subheadline, weight: isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(color, lineWidth: 1)
                        .opacity(isSelected ? 0 : 0.3)
                )
        }
    }
}

// MARK: - Route Overlay View
struct RouteOverlayView: View {
    let coordinates: [CLLocationCoordinate2D]
    let dayColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !coordinates.isEmpty else { return }
                
                // 将经纬度坐标转换为屏幕坐标（简化版本，实际需要更复杂的转换）
                // 注意：这是一个简化实现，真实的地图投影会更复杂
                let points = coordinates.map { coordinate -> CGPoint in
                    // 这里需要根据当前地图区域进行坐标转换
                    // 简化版本：假设线性映射
                    let x = (coordinate.longitude + 180) / 360 * geometry.size.width
                    let y = (90 - coordinate.latitude) / 180 * geometry.size.height
                    return CGPoint(x: x, y: y)
                }
                
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(dayColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [10, 5]))
            .opacity(0.7)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Day Marker View
struct DayMarkerView: View {
    let index: Int
    let day: Int?
    
    // 根据天数返回不同颜色
    var markerColor: Color {
        guard let day = day else { return .blue }
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        return colors[(day - 1) % colors.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            
            Text("\(index)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
