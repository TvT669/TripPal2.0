//
//  PlanResultView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/31.
//

import SwiftUI

/// 结构化旅行方案展示视图
struct PlanResultView: View {
    let plan: TravelPlanModel
    @EnvironmentObject var tripStore: TripStore
    @StateObject private var organizerAgent = OrganizerAgent() // ✅ 引入智能整理智能体
    @State private var isSaved = false
    @State private var isSaving = false // ✅ 添加保存中状态
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. 摘要文本
            Text(plan.summaryText)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            // 2. 预算仪表盘
            BudgetDashboardCell(status: plan.budgetStatus)
            
            // 3. 风险提示条 (如果有)
            if !plan.riskWarnings.isEmpty {
                RiskAlertBanner(warnings: plan.riskWarnings)
            }
            
            // 4. 行程时间轴
            Text("行程安排")
                .font(.headline)
                .padding(.top, 8)
            
            ItineraryTimelineView(days: plan.itinerary)
            
            // 5. 一键保存按钮
            if isSaved {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已保存到\"我的行程\"")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Spacer()
                    // 提示用户去另一个标签页查看
                    Text("请切换标签页查看")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: {
                    Task {
                        await saveToMyTrips()
                    }
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("正在生成智能行程...")
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("一键保存行程")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSaving ? Color.gray : Color.chiikawaPink)
                    .cornerRadius(12)
                    .shadow(color: isSaving ? .clear : Color.chiikawaPink.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(isSaving)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func saveToMyTrips() async {
        isSaving = true
        
        do {
            // 1. 将 TravelPlanModel 转换为 ParsedPlace 列表
            // 这里我们跳过 extractPlaces 步骤，因为数据已经是结构化的了
            let parsedPlaces = convertToParsedPlaces(plan)
            
            // 2. 调用 OrganizerAgent 进行地理编码和行程丰富
            // 这会通过 AMapService 查找真实坐标
            let finalTripPlan = try await organizerAgent.generatePlan(from: parsedPlaces)
            
            // 3. 保存到 Store
            await MainActor.run {
                tripStore.addPlan(finalTripPlan)
                
                // 触觉反馈
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                withAnimation {
                    isSaved = true
                    isSaving = false
                }
            }
            
        } catch {
            print("❌ 保存行程失败: \(error)")
            await MainActor.run {
                isSaving = false
            }
        }
    }
    
    // 将 AI 返回的 JSON 模型转换为 OrganizerAgent 可处理的中间格式
    private func convertToParsedPlaces(_ model: TravelPlanModel) -> [ParsedPlace] {
        var places: [ParsedPlace] = []
        
        for day in model.itinerary {
            for activity in day.activities {
                let place = ParsedPlace(
                    name: activity,
                    originalText: "Day \(day.day): \(day.title) - \(activity)",
                    isSelected: true,
                    day: day.day
                )
                places.append(place)
            }
        }
        
        return places
    }
}

// MARK: - 子组件

/// 预算仪表盘
struct BudgetDashboardCell: View {
    let status: BudgetStatus
    
    var progress: Double {
        guard status.totalBudget > 0 else { return 0 }
        return min(status.estimatedCost / status.totalBudget, 1.5) // 允许超过100%显示
    }
    
    var isOverBudget: Bool {
        status.isOverBudget
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("预算分析", systemImage: "yensign.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(status.verdict)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isOverBudget ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundColor(isOverBudget ? .red : .green)
                    .cornerRadius(8)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景槽
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // 进度
                    Rectangle()
                        .fill(isOverBudget ? Color.red : Color.green)
                        .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // 数值
            HStack {
                Text("预算: ¥\(Int(status.totalBudget))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("预估: ¥\(Int(status.estimatedCost))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isOverBudget ? .red : .primary)
            }
            
            if isOverBudget {
                Text("⚠️ 超出预算 ¥\(Int(status.estimatedCost - status.totalBudget))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

/// 风险提示条
struct RiskAlertBanner: View {
    let warnings: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .padding(.top, 2)
                    
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 行程时间轴
struct ItineraryTimelineView: View {
    let days: [DailyItinerary]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 12) {
                        // 头部
                        HStack {
                            Text("Day \(day.day)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Text("¥\(Int(day.costEstimate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(day.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Divider()
                        
                        // 活动列表
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(day.activities.prefix(3), id: \.self) { activity in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .padding(.top, 6)
                                        .foregroundColor(.blue)
                                    
                                    Text(activity)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            if day.activities.count > 3 {
                                Text("+\(day.activities.count - 3) 更多...")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.leading, 10)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .frame(width: 160, height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, 4) // 为阴影留出空间
        }
    }
}
