//
//  LegacyContentView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/9/2.
//

import SwiftUI

/// AI 智能助手界面 
struct LegacyContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var userInput = ""
    @State private var chatMessages: [DisplayMessage] = []
    @State private var showingQuickActions = false
    @State private var selectedQuickAction: QuickAction?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.cyan.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 智能状态栏
                    if !chatMessages.isEmpty || appState.isLoading {
                        StatusBarView(
                            isLoading: appState.isLoading,
                            messageCount: chatMessages.count,
                            onClear: clearChat
                        )
                    }
                    
                    // 主聊天区域
                    ChatAreaView(
                        messages: $chatMessages,
                        isLoading: appState.isLoading,
                        isEmpty: chatMessages.isEmpty,
                        onQuickAction: { action in
                            selectedQuickAction = action
                            userInput = action.text
                            sendMessage()
                        }
                    )
                    
                    // 智能输入区域
                    InputAreaView(
                        userInput: $userInput,
                        isLoading: appState.isLoading,
                        isInputFocused: $isInputFocused,
                        onSend: sendMessage,
                        onQuickActions: { showingQuickActions.toggle() }
                    )
                }
            }
            .navigationTitle("AI 旅行助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { showingQuickActions.toggle() }) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        if !chatMessages.isEmpty {
                            Button("清空", action: clearChat)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        NavigationLink(destination: SettingView()) {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingQuickActions) {
                QuickActionsSheet(onActionSelected: { action in
                    selectedQuickAction = action
                    userInput = action.text
                    showingQuickActions = false
                    // 延迟发送，让 sheet 先关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        sendMessage()
                    }
                })
            }
            .alert(isPresented: .constant(appState.errorMessage != nil)) {
                Alert(
                    title: Text("❌ 出现错误"),
                    message: Text(appState.errorMessage ?? "未知错误"),
                    dismissButton: .default(Text("确定")) {
                        appState.errorMessage = nil
                    }
                )
            }
            .onChange(of: appState.response) { _, newResponse in
                if !newResponse.isEmpty {
                    addAssistantMessage(newResponse)
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 添加用户消息到UI
        let userMessage = DisplayMessage(
            id: UUID().uuidString,
            role: .user,
            content: userInput,
            timestamp: Date(),
            quickAction: selectedQuickAction
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            chatMessages.append(userMessage)
        }
        
        // 保存用户输入并清空
        let input = userInput
        userInput = ""
        selectedQuickAction = nil
        isInputFocused = false
        
        // 执行请求
        Task {
            await appState.executeRequest(input)
        }
    }
    
    private func addAssistantMessage(_ content: String) {
        // 先清理 DSML 标记
        var cleanedContent = content
        
        // 移除所有 DSML 相关内容
        let dsmlPatterns = [
            "<\\s*\\|\\s*DSML[^>]*>",                    // < | DSML ... >
            "</\\s*\\|\\s*DSML[^>]*>",                   // </ | DSML ... >
            "function_calls?>",                           // function_calls>
            "invoke[^>]*>",                               // invoke...>
            "parameter[^>]*>",                            // parameter...>
        ]
        
        for pattern in dsmlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(cleanedContent.startIndex..., in: cleanedContent)
                cleanedContent = regex.stringByReplacingMatches(
                    in: cleanedContent,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }
        
        // 清理后再判断是否为空
        let trimmedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果清理后内容为空,不显示
        guard !trimmedContent.isEmpty else {
            print("⚠️ 跳过空消息或纯 DSML 标记: \(content.prefix(50))...")
            return
        }
        
        let assistantMessage = DisplayMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: trimmedContent,  // 使用清理后的内容
            timestamp: Date()
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            chatMessages.append(assistantMessage)
        }
    }
    
    private func clearChat() {
        withAnimation(.easeInOut(duration: 0.5)) {
            chatMessages.removeAll()
        }
        appState.response = ""
    }
}

// MARK: - 子视图组件

/// 状态栏视图
struct StatusBarView: View {
    let isLoading: Bool
    let messageCount: Int
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "message.fill")
                    .foregroundColor(.blue)
                Text("\(messageCount)条对话")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI思考中...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .animation(.easeInOut, value: isLoading)
    }
}

/// 聊天区域视图
struct ChatAreaView: View {
    @Binding var messages: [DisplayMessage]
    let isLoading: Bool
    let isEmpty: Bool
    let onQuickAction: (QuickAction) -> Void
    
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if isEmpty {
                        WelcomeView(onQuickAction: onQuickAction)
                    } else {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        if isLoading {
                            TypingIndicatorView()
                                .id("typing")
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.5)) {
                    if let lastMessage = messages.last {
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollView.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// 欢迎界面
struct WelcomeView: View {
    let onQuickAction: (QuickAction) -> Void
    @State private var isAnimating = true
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 欢迎图标
            VStack(spacing: 16) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.0 : 1.1)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(spacing: 8) {
                    
                    Text("您的专业AI旅行规划助手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // 快捷操作
            VStack(spacing: 12) {
                Text("🚀 快速开始")
                    .font(.headline)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(QuickAction.welcomeActions, id: \.id) { action in
                        QuickActionCard(action: action) {
                            onQuickAction(action)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

/// 快捷操作卡片
struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(action.icon)
                    .font(.title2)
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 输入区域视图
struct InputAreaView: View {
    @Binding var userInput: String
    let isLoading: Bool
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void
    let onQuickActions: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 智能建议（如果有的话）
            if !userInput.isEmpty && userInput.count > 2 {
                SuggestionBarView(input: userInput) { suggestion in
                    userInput = suggestion
                }
            }
            
            // 输入栏
            HStack(spacing: 12) {
                Button(action: onQuickActions) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                TextField("描述您的旅行需求...", text: $userInput, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .disabled(isLoading)
                    .onSubmit {
                        if !isLoading {
                            onSend()
                        }
                    }
                
                Button(action: onSend) {
                    Image(systemName: isLoading ? "hourglass" : "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                        .animation(.easeInOut, value: isLoading)
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    private var canSend: Bool {
        !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}

/// 智能建议栏
struct SuggestionBarView: View {
    let input: String
    let onSuggestion: (String) -> Void
    
    private var suggestions: [String] {
        let lowercased = input.lowercased()
        var suggestions: [String] = []
        
        if lowercased.contains("去") || lowercased.contains("旅游") {
            suggestions.append("我想去日本旅游，请帮我制定详细计划")
        }
        if lowercased.contains("机票") || lowercased.contains("航班") {
            suggestions.append("帮我查找北京到上海的航班信息")
        }
        if lowercased.contains("酒店") || lowercased.contains("住宿") {
            suggestions.append("推荐上海市中心性价比高的酒店")
        }
        if lowercased.contains("预算") {
            suggestions.append("帮我分析这次旅行的预算构成")
        }
        
        return Array(suggestions.prefix(2))
    }
    
    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            onSuggestion(suggestion)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// 打字指示器
struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = -50
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.blue)
            
            Text("AI正在思考")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffset)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            animationOffset = 10
        }
    }
}

// MARK: - 消息展示模型

struct DisplayMessage: Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    var base64Image: String? = nil
    var quickAction: QuickAction? = nil
    
    enum MessageRole {
        case user
        case assistant
        case system
        
        var displayName: String {
            switch self {
            case .user: return "您"
            case .assistant: return "AI助手"
            case .system: return "系统"
            }
        }
        
        var icon: String {
            switch self {
            case .user: return "person.circle.fill"
            case .assistant: return "brain.head.profile"
            case .system: return "gear.circle.fill"
            }
        }
    }
}

// MARK: - 消息视图

struct MessageView: View {
    let message: DisplayMessage
    
    /// 清理DSML标记后的内容
    private var cleanedContent: String {
        var content = message.content
        
        // 移除所有 DSML 相关标记（更全面的模式）
        let dsmlPatterns = [
            "<\\s*\\|\\s*DSML\\s*\\|[^>]*>",           // < | DSML | ... >
            "</\\s*\\|\\s*DSML\\s*\\|[^>]*>",          // </ | DSML | ... >
            "<\\s*\\|\\s*DSML\\s*\\|[^<]*</\\s*\\|\\s*DSML\\s*\\|[^>]*>",  // 完整标签对
            "function_calls?",                           // function_call 关键字
            "invoke\\s+name=",                           // invoke name=
            "parameter\\s+name=",                        // parameter name=
            "string\\s*=\\s*\"true\"",                    // string="true"
        ]
        
        for pattern in dsmlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(content.startIndex..., in: content)
                content = regex.stringByReplacingMatches(
                    in: content,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }
        
        // 移除多余的空白行
        let lines = content.components(separatedBy: "\n")
        let cleanedLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        content = cleanedLines.joined(separator: "\n")
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role != .user {
                // AI头像
                Image(systemName: message.role.icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // 快捷操作标签
                if let quickAction = message.quickAction {
                    HStack(spacing: 4) {
                        Text(quickAction.icon)
                            .font(.caption2)
                        Text(quickAction.title)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 消息内容
                Text(cleanedContent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(18)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = cleanedContent
                        }) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
                
                // 图片显示
                if let base64Image = message.base64Image,
                   let imageData = Data(base64Encoded: base64Image),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 200)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                }
                
                // 时间戳
                HStack(spacing: 4) {
                    if message.role == .assistant {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if message.role == .user {
                // 用户头像
                Image(systemName: message.role.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
        // ✅ 修复 padding 语法
        .padding(.leading, message.role == .user ? 50 : 0)
        .padding(.trailing, message.role == .user ? 0 : 50)
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return Color(.systemGray6)
        }
    }
    
    private var textColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return .primary
        }
    }
}

// MARK: - 快捷操作

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let category: Category
    
    enum Category {
        case planning, flight, hotel, budget, route
    }
    
    static let welcomeActions: [QuickAction] = [
        QuickAction(
            icon: "✈️",
            title: "查找航班",
            text: "帮我查找北京到上海明天的航班",
            category: .flight
        ),
        QuickAction(
            icon: "🏨",
            title: "预订酒店",
            text: "推荐上海外滩附近性价比高的酒店",
            category: .hotel
        ),
        QuickAction(
            icon: "🗺️",
            title: "制定路线",
            text: "帮我制定3天2夜的上海旅游路线",
            category: .route
        ),
        QuickAction(
            icon: "💰",
            title: "预算分析",
            text: "分析去日本7天旅游需要多少预算",
            category: .budget
        )
    ]
}

/// 快捷操作面板
struct QuickActionsSheet: View {
    let onActionSelected: (QuickAction) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let allActions: [QuickAction] = [
        // 行程规划
        QuickAction(icon: "🎯", title: "制定旅行计划", text: "我想去日本旅游7天，帮我制定详细的行程计划", category: .planning),
        QuickAction(icon: "⏰", title: "周末游计划", text: "推荐北京周边适合周末游的地方", category: .planning),
        
        // 航班相关
        QuickAction(icon: "✈️", title: "查找航班", text: "帮我查找北京到东京的航班信息", category: .flight),
        QuickAction(icon: "🎫", title: "特价机票", text: "有什么特价机票推荐吗？", category: .flight),
        
        // 酒店住宿
        QuickAction(icon: "🏨", title: "预订酒店", text: "推荐东京市中心性价比高的酒店", category: .hotel),
        QuickAction(icon: "🏡", title: "民宿推荐", text: "推荐一些有特色的民宿", category: .hotel),
        
        // 预算管理
        QuickAction(icon: "💰", title: "预算分析", text: "分析去欧洲15天旅游的预算构成", category: .budget),
        QuickAction(icon: "💳", title: "省钱攻略", text: "有什么旅游省钱的好方法？", category: .budget)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(QuickAction.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.title)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(actionsForCategory(category), id: \.id) { action in
                                    QuickActionCard(action: action) {
                                        onActionSelected(action)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("🚀 快速开始")
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
    
    private func actionsForCategory(_ category: QuickAction.Category) -> [QuickAction] {
        allActions.filter { $0.category == category }
    }
}

// ✅ 添加 CaseIterable 协议实现
extension QuickAction.Category: CaseIterable {
    static var allCases: [QuickAction.Category] {
        [.planning, .flight, .hotel, .budget]
    }
    
    var title: String {
        switch self {
        case .planning: return "🎯 行程规划"
        case .flight: return "✈️ 航班机票"
        case .hotel: return "🏨 酒店住宿"
        case .budget: return "💰 预算管理"
        case .route: return "🗺️ 路线规划"
        }
    }
}
#Preview {
    LegacyContentView()
}
