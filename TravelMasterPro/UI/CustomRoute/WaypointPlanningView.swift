//
//  WaypointPlanningView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/25.
//
import SwiftUI
import MapKit

struct WaypointPlanningView: View {
    @Binding var route: CustomRoute
    @State private var calculatedRoutes: [MKRoute] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // 分日器状态
    @State private var selectedDay: Int = 1
    @State private var totalDays: Int = 1
    
    var currentWaypoints: [TripNode] {
        route.waypoints.filter { ($0.day ?? 1) == selectedDay }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 分日器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(1...totalDays, id: \.self) { day in
                        Button(action: {
                            selectedDay = day
                            recalculateRoute()
                        }) {
                            Text("Day \(day)")
                                .chiikawaFont(.subheadline, weight: selectedDay == day ? .bold : .regular)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedDay == day ? Color.chiikawaBlue : Color.chiikawaBlue.opacity(0.1))
                                .foregroundColor(selectedDay == day ? .white : .chiikawaBlue)
                                .cornerRadius(20)
                        }
                    }
                    
                    Button(action: {
                        totalDays += 1
                        selectedDay = totalDays
                        recalculateRoute()
                    }) {
                        Image(systemName: "plus")
                            .padding(8)
                            .background(Color.chiikawaPink.opacity(0.2))
                            .foregroundColor(.chiikawaPink)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.chiikawaWhite)
            
            ZStack(alignment: .topTrailing) {
                if #available(iOS 17.0, *) {
                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            ForEach(Array(currentWaypoints.enumerated()), id: \.element.id) { index, node in
                                Annotation(node.name, coordinate: node.clCoordinate) {
                                    NumberedMarker(number: index + 1)
                                }
                            }
                            
                            ForEach(calculatedRoutes, id: \.self) { route in
                                MapPolyline(route)
                                    .stroke(Color.chiikawaPink, lineWidth: 5)
                            }
                            
                            UserAnnotation()
                        }
                        .onTapGesture { position in
                            if let coordinate = proxy.convert(position, from: .local) {
                                addWaypoint(at: coordinate)
                            }
                        }
                    }
                } else {
                    Map(position: $cameraPosition) {
                        ForEach(Array(currentWaypoints.enumerated()), id: \.element.id) { index, node in
                            Annotation(node.name, coordinate: node.clCoordinate) {
                                NumberedMarker(number: index + 1)
                            }
                        }
                        
                        ForEach(calculatedRoutes, id: \.self) { route in
                            MapPolyline(route)
                                .stroke(Color.chiikawaPink, lineWidth: 5)
                        }
                    }
                }
            }
            .frame(height: 300)
            .cornerRadius(24)
            .shadow(color: .chiikawaText.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding()
            
            List {
                Section(header: HStack {
                    Text("Day \(selectedDay) 途经点")
                        .chiikawaFont(.headline, weight: .bold)
                    Spacer()
                    EditButton() // 开启排序模式
                        .foregroundColor(.chiikawaPink)
                }) {
                    ForEach(Array(currentWaypoints.enumerated()), id: \.element.id) { index, node in
                        HStack {
                            // 列表显示对应数字
                            ZStack {
                                Circle()
                                    .fill(Color.chiikawaPink)
                                    .frame(width: 24, height: 24)
                                Text("\(index + 1)")
                                    .foregroundColor(.white)
                                    .font(.caption.bold())
                            }
                            Text(node.name)
                                .chiikawaFont()
                        }
                        .listRowBackground(Color.white)
                    }
                    .onMove { indices, newOffset in
                        moveWaypoint(from: indices, to: newOffset)
                    }
                    .onDelete { indices in
                        deleteWaypoint(at: indices)
                    }
                }
                
                Section {
                    Toggle("闭环路线 (回到起点)", isOn: $route.isLoop)
                        .onChange(of: route.isLoop) { _ in recalculateRoute() }
                        .tint(.chiikawaPink)
                }
                
                Button(action: { isSearching = true }) {
                    Label("搜索添加地点", systemImage: "magnifyingglass")
                        .foregroundColor(.chiikawaBlue)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.chiikawaWhite)
        }
        .background(Color.chiikawaWhite)
        .sheet(isPresented: $isSearching) {
            PlaceSearchSheet(region: searchRegion) { mapItem in
                let node = TripNode(
                    name: mapItem.name ?? "未知地点",
                    description: mapItem.placemark.title ?? "",
                    day: selectedDay, // 设置为当前天
                    coordinate: TripNode.Coordinate(
                        latitude: mapItem.placemark.coordinate.latitude,
                        longitude: mapItem.placemark.coordinate.longitude
                    )
                )
                route.waypoints.append(node)
                recalculateRoute()
                isSearching = false
            }
        }
        .onAppear {
            // 初始化总天数
            let maxDay = route.waypoints.compactMap { $0.day }.max() ?? 1
            totalDays = max(maxDay, 1)
            recalculateRoute()
        }
    }
    
    // 计算搜索区域：优先使用当前天最后一个途经点附近
    var searchRegion: MKCoordinateRegion? {
        if let lastNode = currentWaypoints.last {
            return MKCoordinateRegion(
                center: lastNode.clCoordinate,
                latitudinalMeters: 20000, // 20km 搜索半径
                longitudinalMeters: 20000
            )
        }
        return nil
    }
    
    func recalculateRoute() {
        Task {
            // 只计算当前天的路线
            calculatedRoutes = await RouteCalculationManager.shared.calculateRoute(for: currentWaypoints, isLoop: route.isLoop)
        }
    }
    
    func addWaypoint(at coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        Task {
            var name = "新标记点"
            var description = ""
            
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                name = placemark.name ?? placemark.thoroughfare ?? "未知地点"
                description = placemark.locality ?? ""
            }
            
            let newNode = TripNode(
                name: name,
                description: description,
                day: selectedDay, // 设置为当前天
                coordinate: TripNode.Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            
            await MainActor.run {
                route.waypoints.append(newNode)
                recalculateRoute()
            }
        }
    }
    
    func moveWaypoint(from source: IndexSet, to destination: Int) {
        var dayNodes = currentWaypoints
        dayNodes.move(fromOffsets: source, toOffset: destination)
        
        // 重建完整列表：保留非当前天的节点，添加排序后的当前天节点
        var otherNodes = route.waypoints.filter { ($0.day ?? 1) != selectedDay }
        otherNodes.append(contentsOf: dayNodes)
        
        // 按天数排序以保持数据整洁
        route.waypoints = otherNodes.sorted { ($0.day ?? 1) < ($1.day ?? 1) }
        
        recalculateRoute()
    }
    
    func deleteWaypoint(at offsets: IndexSet) {
        var dayNodes = currentWaypoints
        dayNodes.remove(atOffsets: offsets)
        
        var otherNodes = route.waypoints.filter { ($0.day ?? 1) != selectedDay }
        otherNodes.append(contentsOf: dayNodes)
        
        route.waypoints = otherNodes.sorted { ($0.day ?? 1) < ($1.day ?? 1) }
        
        recalculateRoute()
    }
}

struct PlaceSearchSheet: View {
    var region: MKCoordinateRegion? // 新增区域参数
    var onSelect: (MKMapItem) -> Void
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @Environment(\.dismiss) var dismiss
    @State private var amapService: AMapService?
    
    var body: some View {
        NavigationView {
            List(results, id: \.self) { item in
                Button(action: { onSelect(item) }) {
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Unknown").font(.headline)
                        Text(item.placemark.title ?? item.placemark.subtitle ?? "").font(.caption)
                    }
                }
            }
            .searchable(text: $query)
            .onChange(of: query) { newValue in
                search(newValue)
            }
            .navigationTitle("搜索地点")
            .toolbar {
                Button("取消") { dismiss() }
            }
        }
        .onAppear {
            // 初始化高德地图服务
            if let config = try? MapConfiguration.load() {
                self.amapService = AMapService(config: config)
            }
        }
    }
    
    func search(_ query: String) {
        guard !query.isEmpty else { return }
        guard let service = amapService else {
            print("AMapService not initialized")
            return
        }
        
        Task {
            do {
                // 构造位置偏好参数
                var locationStr: String? = nil
                if let center = region?.center {
                    locationStr = String(format: "%.6f,%.6f", center.longitude, center.latitude)
                }
                
                // 不再限制搜索类型，以确保能搜到所有地点（如五一广场）
                // 但在结果中过滤掉普通公交站(150700)以避免干扰
                let allPois = try await service.searchPOI(keyword: query, types: nil, location: locationStr)
                
                // 过滤掉公交站
                let pois = allPois.filter { poi in
                    guard let typecode = poi.typecode else { return true }
                    return !typecode.hasPrefix("1507")
                }
                
                let items = pois.compactMap { poi -> MKMapItem? in
                    guard let location = parseLocation(poi.location) else { return nil }
                    
                    // 构建 MKPlacemark
                    // 使用 addressDictionary 来填充地址信息，以便 placemark.title 能显示内容
                    let addressDict: [String: Any] = [
                        "Name": poi.name,
                        "Thoroughfare": poi.address ?? "",
                        "City": poi.cityname ?? ""
                    ]
                    
                    let placemark = MKPlacemark(coordinate: location, addressDictionary: addressDict)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = poi.name
                    return mapItem
                }
                
                await MainActor.run {
                    self.results = items
                }
            } catch {
                print("AMap search failed: \(error)")
            }
        }
    }
    
    private func parseLocation(_ location: String) -> CLLocationCoordinate2D? {
        let parts = location.split(separator: ",")
        guard parts.count == 2,
              let lng = Double(parts[0]),
              let lat = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - 自定义数字标记视图
struct NumberedMarker: View {
    let number: Int
    
    var body: some View {
        ZStack {
            // 白色背景边框
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
                .shadow(color: .chiikawaPink.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // 红色背景
            Circle()
                .fill(Color.chiikawaPink)
                .frame(width: 26, height: 26)
            
            // 数字
            Text("\(number)")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
    }
}
