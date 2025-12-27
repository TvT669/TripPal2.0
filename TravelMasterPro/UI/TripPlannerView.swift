//
//  TripPlannerView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/9/2.
//

import SwiftUI

/// 行程规划界面
struct TripPlannerView: View {
    @StateObject private var tripManager = TripManager()
    @State private var showingNewTrip = false
    
    var body: some View {
        NavigationView {
            VStack {
                if tripManager.trips.isEmpty {
                    TripEmptyView(onCreateTrip: { showingNewTrip = true })
                } else {
                    TripListView(trips: tripManager.trips)
                }
            }
            .navigationTitle("我的行程")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewTrip = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NewTripView(tripManager: tripManager)
            }
        }
    }
}

/// 空行程视图
struct TripEmptyView: View {
    let onCreateTrip: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("还没有行程计划")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("创建您的第一个旅行计划")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onCreateTrip) {
                Text("创建新行程")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

/// 行程列表视图
struct TripListView: View {
    let trips: [Trip]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(trips) { trip in
                    TripCard(trip: trip)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// 行程卡片
struct TripCard: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                    
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trip.dateRange)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("\(trip.duration) 天")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("\(trip.activities.count) 项活动", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("预算 ¥\(trip.budget)", systemImage: "yensign.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// 新建行程视图
struct NewTripView: View {
    @ObservedObject var tripManager: TripManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tripName = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 3)
    @State private var budget = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("行程名称", text: $tripName)
                    TextField("目的地", text: $destination)
                }
                
                Section(header: Text("日期")) {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                }
                
                Section(header: Text("预算（可选）")) {
                    TextField("预算金额", text: $budget)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button(action: createTrip) {
                        Text("创建行程")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(tripName.isEmpty || destination.isEmpty)
                }
            }
            .navigationTitle("新建行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func createTrip() {
        let trip = Trip(
            name: tripName,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            budget: Int(budget) ?? 0
        )
        tripManager.addTrip(trip)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - 数据模型和管理器

class TripManager: ObservableObject {
    @Published var trips: [Trip] = []
    
    func addTrip(_ trip: Trip) {
        trips.append(trip)
    }
}

struct Trip: Identifiable {
    let id = UUID()
    let name: String
    let destination: String
    let startDate: Date
    let endDate: Date
    let budget: Int
    var activities: [Activity] = []
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var duration: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
    }
}

struct Activity: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let time: Date
}

#Preview {
    TripPlannerView()
}
