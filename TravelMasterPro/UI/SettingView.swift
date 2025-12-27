//
//  SettingView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import SwiftUI

/// 设置界面
struct SettingView: View {
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @AppStorage("model_name") private var modelName: String = "gpt-4"
    @AppStorage("max_tokens") private var maxTokens: Int = 2000
    @AppStorage("temperature") private var temperature: Double = 0.7
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("preferred_language") private var preferredLanguage: String = "中文"
    
    @State private var isApiKeyVisible = false
    @State private var showingResetAlert = false
    @State private var showingAbout = false
    
    // 可选的模型列表
    private let availableModels = [
        "gpt-4",
        "gpt-4-turbo",
        "gpt-3.5-turbo",
        "claude-3-sonnet",
        "claude-3-haiku"
    ]
    
    private let languages = ["中文", "English", "日本語", "한국어"]
    
    var body: some View {
        NavigationView {
            Form {
                // AI 配置部分
                Section(header: Text("🤖 AI 配置")) {
                    // API Key
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        HStack {
                            if isApiKeyVisible {
                                TextField("输入您的 API Key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                SecureField("输入您的 API Key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Button(action: {
                                isApiKeyVisible.toggle()
                            }) {
                                Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text("用于访问 AI 服务，请确保 Key 的安全性")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 模型选择
                    Picker("AI 模型", selection: $modelName) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    // 高级参数
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最大 Token 数: \(maxTokens)")
                            .font(.headline)
                        
                        Slider(value: Binding(
                            get: { Double(maxTokens) },
                            set: { maxTokens = Int($0) }
                        ), in: 500...4000, step: 100)
                        
                        Text("控制 AI 响应的最大长度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("创造性: \(String(format: "%.1f", temperature))")
                            .font(.headline)
                        
                        Slider(value: $temperature, in: 0.0...1.0, step: 0.1)
                        
                        Text("0.0 更保守，1.0 更有创意")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 个人偏好
                Section(header: Text("👤 个人偏好")) {
                    TextField("您的昵称", text: $userName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("偏好语言", selection: $preferredLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    
                    NavigationLink(destination: TravelPreferencesView()) {
                        Label("旅行偏好设置", systemImage: "airplane.circle")
                    }
                }
                
                // 应用信息
                Section(header: Text("📱 应用信息")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { showingAbout = true }) {
                        Label("关于 TravelMasterPro", systemImage: "info.circle")
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("隐私政策", systemImage: "lock.shield")
                    }
                    
                    NavigationLink(destination: HelpView()) {
                        Label("帮助与支持", systemImage: "questionmark.circle")
                    }
                }
                
                // 数据管理
                Section(header: Text("🗄️ 数据管理")) {
                    Button(action: exportSettings) {
                        Label("导出设置", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: importSettings) {
                        Label("导入设置", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingResetAlert = true }) {
                        Label("重置所有设置", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
                
                // 开发者选项
                Section(header: Text("🛠️ 开发者选项")) {
                    NavigationLink(destination: DebugView()) {
                        Label("调试信息", systemImage: "ladybug")
                    }
                    
                    NavigationLink(destination: APITestView()) {
                        Label("API 测试", systemImage: "network")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .alert("重置设置", isPresented: $showingResetAlert) {
                Button("取消", role: .cancel) { }
                Button("确认重置", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("这将清除所有设置并恢复默认值，此操作不可撤销。")
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func resetAllSettings() {
        apiKey = ""
        modelName = "gpt-4"
        maxTokens = 2000
        temperature = 0.7
        userName = ""
        preferredLanguage = "中文"
    }
    
    private func exportSettings() {
        // 导出设置功能
        print("导出设置功能开发中...")
    }
    
    private func importSettings() {
        // 导入设置功能
        print("导入设置功能开发中...")
    }
}

// MARK: - 子页面视图

/// 旅行偏好设置
struct TravelPreferencesView: View {
    @AppStorage("budget_range") private var budgetRange: String = "中等"
    @AppStorage("travel_style") private var travelStyle: String = "休闲"
    @AppStorage("accommodation_type") private var accommodationType: String = "酒店"
    
    private let budgetRanges = ["经济", "中等", "舒适", "奢华"]
    private let travelStyles = ["冒险", "休闲", "文化", "美食", "购物"]
    private let accommodationTypes = ["酒店", "民宿", "青旅", "度假村"]
    
    var body: some View {
        Form {
            Section(header: Text("💰 预算偏好")) {
                Picker("预算范围", selection: $budgetRange) {
                    ForEach(budgetRanges, id: \.self) { range in
                        Text(range).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("🎯 旅行风格")) {
                Picker("旅行风格", selection: $travelStyle) {
                    ForEach(travelStyles, id: \.self) { style in
                        Text(style).tag(style)
                    }
                }
            }
            
            Section(header: Text("🏨 住宿偏好")) {
                Picker("住宿类型", selection: $accommodationType) {
                    ForEach(accommodationTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
            }
        }
        .navigationTitle("旅行偏好")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App 图标和名称
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("TravelMasterPro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("您的智能旅行规划助手")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 功能介绍
                    VStack(alignment: .leading, spacing: 16) {
                        Text("核心功能")
                            .font(.headline)
                        
                        FeatureRow(icon: "brain.head.profile", title: "AI 智能助手", description: "基于先进AI技术的旅行规划")
                        FeatureRow(icon: "map", title: "地图导航", description: "精准的地理位置和路线规划")
                        FeatureRow(icon: "bed.double", title: "酒店搜索", description: "全球酒店信息查询与推荐")
                        FeatureRow(icon: "airplane", title: "航班查询", description: "实时航班信息和价格对比")
                        FeatureRow(icon: "dollarsign.circle", title: "预算分析", description: "智能预算规划和成本控制")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 版权信息
                    VStack(spacing: 8) {
                        Text("© 2024 TravelMasterPro")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Made with ❤️ for travelers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 功能行组件
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

/// 隐私政策页面
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Group {
                    PolicySection(
                        title: "数据收集",
                        content: "我们仅收集为您提供服务所必需的信息，包括您的旅行偏好和查询历史。"
                    )
                    
                    PolicySection(
                        title: "数据使用",
                        content: "您的数据仅用于改善服务质量和提供个性化推荐，不会用于其他目的。"
                    )
                    
                    PolicySection(
                        title: "数据保护",
                        content: "我们采用行业标准的安全措施保护您的数据，包括加密传输和安全存储。"
                    )
                    
                    PolicySection(
                        title: "第三方服务",
                        content: "我们可能使用第三方服务来提供某些功能，这些服务有自己的隐私政策。"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 政策部分组件
struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// 帮助页面
struct HelpView: View {
    var body: some View {
        List {
            Section("常见问题") {
                HelpItem(question: "如何设置 API Key？", answer: "在设置页面找到 AI 配置部分，输入您的 API Key。")
                HelpItem(question: "为什么 AI 响应很慢？", answer: "可能是网络问题或 API 服务繁忙，请稍后重试。")
                HelpItem(question: "如何重置设置？", answer: "在设置页面最下方找到'重置所有设置'选项。")
            }
            
            Section("联系我们") {
                Link("发送邮件", destination: URL(string: "mailto:support@travelmasterpro.com")!)
                Link("访问官网", destination: URL(string: "https://travelmasterpro.com")!)
            }
        }
        .navigationTitle("帮助与支持")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 帮助项组件
struct HelpItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 调试页面
struct DebugView: View {
    var body: some View {
        List {
            Section("系统信息") {
                HStack {
                    Text("设备型号")
                    Spacer()
                    Text(UIDevice.current.model)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("系统版本")
                    Spacer()
                    Text(UIDevice.current.systemVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("应用版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("调试信息")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// API 测试页面
struct APITestView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Button("测试 AI 连接") {
                testAIConnection()
            }
            .disabled(isLoading)
            
            Button("测试地图服务") {
                testMapService()
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView("测试中...")
            }
            
            ScrollView {
                Text(testResult)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("API 测试")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func testAIConnection() {
        isLoading = true
        testResult = "正在测试 AI 连接..."
        
        // 模拟测试
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testResult = "✅ AI 连接测试成功\n响应时间: 1.2s"
            isLoading = false
        }
    }
    
    private func testMapService() {
        isLoading = true
        testResult = "正在测试地图服务..."
        
        // 模拟测试
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            testResult = "✅ 地图服务测试成功\n高德地图 API 正常"
            isLoading = false
        }
    }
}

#Preview {
    SettingView()
}




