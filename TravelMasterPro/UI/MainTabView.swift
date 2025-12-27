//
//  MainTabView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/9/2.
//

import SwiftUI

/// 主导航视图 - 整合所有功能模块
struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // AI 助手页面 - 使用您现有的完整功能页面
            LegacyContentView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI 助手")
                }
                .tag(0)
            
            // 我的行程页面
            MyTripsView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("我的行程")
                }
                .tag(1)
        }
        .accentColor(.blue)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMainTab"))) { notification in
            if let tabIndex = notification.object as? Int {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = tabIndex
                }
            }
        }
    }
        
}

#Preview {
    MainTabView()
}


