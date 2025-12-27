//
//  MyTripsView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import SwiftUI
import MapKit

struct MyTripsView: View {
    @StateObject private var tripStore = TripStore()
    @StateObject private var organizerAgent = OrganizerAgent()
    
    @State private var showInputSheet = false
    @State private var messyInput = ""
    @State private var showConfirmation = false
    @State private var tempParsedPlaces: [ParsedPlace] = []
    @State private var showCustomRoutePlanner = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if tripStore.plans.isEmpty && tripStore.customRoutes.isEmpty {
                    // 空状态
                    VStack {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("还没有行程")
                            .font(.headline)
                            .padding(.top)
                        Text("点击右上角，把乱七八糟的攻略丢给我")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 行程列表
                    List {
                        if !tripStore.plans.isEmpty {
                            Section(header: Text("AI 智能行程")) {
                                ForEach(tripStore.plans) { plan in
                                    NavigationLink(destination: TripDetailView(plan: plan)) {
                                        VStack(alignment: .leading) {
                                            Text(plan.title)
                                                .font(.headline)
                                            Text("\(plan.nodes.count) 个地点")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(plan.createDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onDelete(perform: tripStore.deletePlan)
                            }
                        }
                        
                        if !tripStore.customRoutes.isEmpty {
                            Section(header: Text("自定义路线")) {
                                ForEach(tripStore.customRoutes) { route in
                                    NavigationLink(destination: CustomRoutePlannerView(route: route).environmentObject(tripStore)) {
                                        VStack(alignment: .leading) {
                                            Text(route.title)
                                                .font(.headline)
                                            Text("\(route.waypoints.count) 个地点")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(route.createDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onDelete(perform: tripStore.deleteRoute)
                            }
                        }
                    }
                }
                
                // 加载状态覆盖层
                if organizerAgent.isProcessing {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text(organizerAgent.progressMessage)
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("我的行程")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showInputSheet = true }) {
                            Label("导入文本行程", systemImage: "doc.text")
                        }
                        Button(action: { showCustomRoutePlanner = true }) {
                            Label("新建自定义路线", systemImage: "map")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showInputSheet) {
                VStack {
                    Text("粘贴你的行程文本")
                        .font(.headline)
                        .padding()
                    
                    TextEditor(text: $messyInput)
                        .frame(height: 200)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                    
                    Button("开始智能识别") {
                        startExtraction()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showConfirmation) {
                PlaceConfirmationView(parsedPlaces: $tempParsedPlaces) { confirmedPlaces in
                    generateFinalTrip(with: confirmedPlaces)
                }
            }
            .sheet(isPresented: $showCustomRoutePlanner) {
                CustomRoutePlannerView().environmentObject(tripStore)
            }
        }
    }
    
    func startExtraction() {
        showInputSheet = false
        
        Task {
            do {
                let places = try await organizerAgent.extractPlaces(from: messyInput)
                await MainActor.run {
                    self.tempParsedPlaces = places
                    self.showConfirmation = true
                }
            } catch {
                print("识别失败: \(error)")
            }
        }
    }
    
    func generateFinalTrip(with places: [ParsedPlace]) {
        Task {
            do {
                let plan = try await organizerAgent.generatePlan(from: places)
                await MainActor.run {
                    tripStore.addPlan(plan)
                    messyInput = ""
                }
            } catch {
                print("生成行程失败: \(error)")
            }
        }
    }
}
