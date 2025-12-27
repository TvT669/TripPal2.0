//
//  CustomRoutePlannerView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/25.
//

import SwiftUI

struct CustomRoutePlannerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: TripStore
    @State private var route: CustomRoute
    
    init(route: CustomRoute? = nil) {
        _route = State(initialValue: route ?? CustomRoute(title: "新路线"))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("路线名称", text: $route.title)
                    .font(.headline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // 仅保留锚点规划模式
                WaypointPlanningView(route: $route)
            }
            .navigationTitle("自定义路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        store.updateRoute(route)
                        dismiss()
                    }
                }
            }
        }
    }
}
