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
                Color.chiikawaWhite.ignoresSafeArea() // Chiikawa 背景色
                
                if tripStore.plans.isEmpty && tripStore.customRoutes.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.chiikawaBlue)
                            .padding()
                            .background(Circle().fill(Color.white).shadow(color: .chiikawaBlue.opacity(0.2), radius: 10))
                        
                        Text("还没有行程哦~")
                            .chiikawaFont(.title2, weight: .bold)
                        
                        Text("点击右上角，把乱七八糟的攻略丢给我吧！")
                            .chiikawaFont(.subheadline)
                            .foregroundColor(.chiikawaSubText)
                    }
                } else {
                    // 行程列表
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if !tripStore.plans.isEmpty {
                                SectionHeaderView(title: "AI 智能行程", icon: "sparkles", color: .chiikawaPink)
                                
                                ForEach(tripStore.plans) { plan in
                                    NavigationLink(destination: TripDetailView(plan: plan)) {
                                        TripListCard(title: plan.title, count: plan.nodes.count, date: plan.createDate, color: .chiikawaPink)
                                    }
                                }
                            }
                            
                            if !tripStore.customRoutes.isEmpty {
                                SectionHeaderView(title: "自定义路线", icon: "map", color: .chiikawaBlue)
                                
                                ForEach(tripStore.customRoutes) { route in
                                    NavigationLink(destination: CustomRoutePlannerView(route: route).environmentObject(tripStore)) {
                                        TripListCard(title: route.title, count: route.waypoints.count, date: route.createDate, color: .chiikawaBlue)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // 加载状态覆盖层
                if organizerAgent.isProcessing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.chiikawaPink)
                            Text(organizerAgent.progressMessage)
                                .chiikawaFont(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .shadow(radius: 10)
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
                            .foregroundColor(.chiikawaPink)
                    }
                }
            }
            .sheet(isPresented: $showInputSheet) {
                VStack(spacing: 20) {
                    Text("粘贴你的行程文本")
                        .chiikawaFont(.title3, weight: .bold)
                        .padding(.top)
                    
                    TextEditor(text: $messyInput)
                        .frame(height: 200)
                        .padding()
                        .background(Color.chiikawaGray)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    
                    Button("开始智能识别") {
                        startExtraction()
                    }
                    .buttonStyle(ChiikawaPrimaryButtonStyle())
                    .padding()
                }
                .presentationDetents([.medium])
                .background(Color.chiikawaWhite)
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

// MARK: - Chiikawa Style Components

struct SectionHeaderView: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .chiikawaFont(.headline, weight: .bold)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

struct TripListCard: View {
    let title: String
    let count: Int
    let date: Date
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .chiikawaFont(.title3, weight: .bold)
                
                HStack {
                    Label("\(count) 个地点", systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.chiikawaSubText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.chiikawaBorder)
        }
        .chiikawaCard()
    }
}


