//
//  UserProfileView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/9/2.
//

import SwiftUI

/// 用户个人页面
struct UserProfileView: View {
    @State private var userName = "旅行达人"
    @State private var userEmail = "travel@example.com"
    @State private var userAvatar = "person.circle.fill"
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    
    // 用户统计数据
    @State private var tripCount = 12
    @State private var countriesVisited = 8
    @State private var totalDays = 45
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ✅ 用户头像和基本信息
                    VStack(spacing: 16) {
                        // 头像
                        Image(systemName: userAvatar)
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 100, height: 100)
                            )
                        
                        // 用户名和邮箱
                        VStack(spacing: 4) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // 编辑按钮
                        Button("编辑资料") {
                            showingEditProfile = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 20)
                    
                    // ✅ 旅行统计
                    VStack(alignment: .leading, spacing: 16) {
                        Text("旅行统计")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            StatisticCard(
                                title: "旅行次数",
                                value: "\(tripCount)",
                                icon: "airplane",
                                color: .blue
                            )
                            
                            StatisticCard(
                                title: "访问国家",
                                value: "\(countriesVisited)",
                                icon: "globe",
                                color: .green
                            )
                            
                            StatisticCard(
                                title: "旅行天数",
                                value: "\(totalDays)",
                                icon: "calendar",
                                color: .orange
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // ✅ 功能菜单
                    VStack(spacing: 12) {
                        Text("功能菜单")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            MenuCard(
                                title: "我的收藏",
                                icon: "heart.fill",
                                color: .red
                            ) {
                                // 跳转到收藏页面
                            }
                            
                            MenuCard(
                                title: "旅行记录",
                                icon: "book.fill",
                                color: .blue
                            ) {
                                // 跳转到旅行记录
                            }
                            
                            MenuCard(
                                title: "设置",
                                icon: "gear",
                                color: .gray
                            ) {
                                showingSettings = true
                            }
                            
                            MenuCard(
                                title: "帮助中心",
                                icon: "questionmark.circle.fill",
                                color: .green
                            ) {
                                // 跳转到帮助中心
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // ✅ 最近活动
                    VStack(alignment: .leading, spacing: 16) {
                        Text("最近活动")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ActivityRow(
                                title: "搜索了北京的酒店",
                                time: "2小时前",
                                icon: "bed.double.fill"
                            )
                            
                            ActivityRow(
                                title: "查看了上海到北京的航班",
                                time: "昨天",
                                icon: "airplane"
                            )
                            
                            ActivityRow(
                                title: "收藏了三亚旅游攻略",
                                time: "3天前",
                                icon: "heart.fill"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(
                    userName: $userName,
                    userEmail: $userEmail,
                    userAvatar: $userAvatar
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - 子组件

/// 统计卡片
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

/// 菜单卡片
struct MenuCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 活动记录行
struct ActivityRow: View {
    let title: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - 编辑资料页面

/// 编辑资料页面
struct EditProfileView: View {
    @Binding var userName: String
    @Binding var userEmail: String
    @Binding var userAvatar: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("用户名")
                        Spacer()
                        TextField("请输入用户名", text: $userName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("邮箱")
                        Spacer()
                        TextField("请输入邮箱", text: $userEmail)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("头像") {
                    HStack {
                        Image(systemName: userAvatar)
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("更换头像") {
                            // 头像选择功能
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 设置页面（简化版）

/// 设置页面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("通用") {
                    HStack {
                        Image(systemName: "bell")
                        Text("推送通知")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "globe")
                        Text("语言")
                        Spacer()
                        Text("中文")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("隐私") {
                    HStack {
                        Image(systemName: "location")
                        Text("位置服务")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                }
                
                Section("关于") {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserProfileView()
}
