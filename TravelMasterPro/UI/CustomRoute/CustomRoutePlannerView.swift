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
            VStack(spacing: 16) {
                TextField("路线名称", text: $route.title)
                    .chiikawaFont(.headline)
                    .padding()
                    .background(Color.chiikawaGray)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 仅保留锚点规划模式
                WaypointPlanningView(route: $route)
            }
            .background(Color.chiikawaWhite.ignoresSafeArea())
            .navigationTitle("自定义路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.chiikawaSubText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        store.updateRoute(route)
                        dismiss()
                    }
                    .foregroundColor(.chiikawaPink)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
