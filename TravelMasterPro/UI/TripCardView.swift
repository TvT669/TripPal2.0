//
//  TripCardView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import SwiftUI

struct TripCardView: View {
    let node: TripNode
    let isLast: Bool
    
    var nodeColor: Color {
        let colors: [Color] = [.chiikawaBlue, .chiikawaPink, .chiikawaYellow, .purple, .orange, .green]
        return colors[((node.day ?? 1) - 1) % 6]
    }
    
    // 根据地点名称智能匹配图标
    private var placeIcon: String {
        let name = node.name
        // 交通
        if name.contains("机场") || name.contains("飞") { return "airplane" }
        if name.contains("站") || name.contains("车") || name.contains("铁") { return "tram.fill" }
        
        // 住宿
        if name.contains("酒店") || name.contains("寓") || name.contains("宿") { return "bed.double.fill" }
        
        // 餐饮
        if name.contains("餐") || name.contains("食") || name.contains("饭") || name.contains("饮") { return "fork.knife" }
        if name.contains("咖啡") || name.contains("茶") { return "cup.and.saucer.fill" }
        
        // 自然/水域
        if name.contains("涌") || name.contains("湾") || name.contains("江") || name.contains("河") || name.contains("湖") || name.contains("海") || name.contains("岛") { return "water.waves" }
        if name.contains("园") || name.contains("山") || name.contains("林") || name.contains("森") { return "tree.fill" }
        
        // 文化/历史
        if name.contains("祠") || name.contains("庙") || name.contains("寺") || name.contains("塔") || name.contains("古") { return "building.columns.fill" }
        if name.contains("馆") || name.contains("展") || name.contains("艺") { return "building.columns.fill" }
        
        // 购物/娱乐
        if name.contains("店") || name.contains("场") || name.contains("街") || name.contains("汇") { return "bag.fill" }
        if name.contains("景") || name.contains("游") { return "camera.fill" }
        
        return "map.fill"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 左侧时间轴线
            VStack(spacing: 0) {
                Circle()
                    .fill(nodeColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: nodeColor.opacity(0.3), radius: 3)
                
                if !isLast {
                    Rectangle()
                        .fill(nodeColor.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 16)
            
            // 右侧卡片内容
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(node.name)
                        .chiikawaFont(.headline, weight: .bold)
                    Spacer()
                    if let time = node.startTime {
                        Text(time, style: .time)
                            .chiikawaFont(.caption)
                            .foregroundColor(.chiikawaSubText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.chiikawaGray)
                            .cornerRadius(8)
                    }
                }
                
                Text(node.description)
                    .chiikawaFont(.subheadline)
                    .foregroundColor(.chiikawaSubText)
                    .lineLimit(3)
                
                // 图片显示
                if let imageData = node.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(nodeColor.opacity(0.1), lineWidth: 1)
                        )
                } else {
                    // 抽象氛围图 (Abstract Banner)
                    ZStack {
                        // 1. 渐变背景
                        LinearGradient(
                            gradient: Gradient(colors: [
                                nodeColor.opacity(0.4),
                                nodeColor.opacity(0.1),
                                Color.white
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // 2. 装饰性巨大图标 (水印效果)
                        GeometryReader { geo in
                            Image(systemName: placeIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.height * 1.5, height: geo.size.height * 1.5)
                                .foregroundColor(nodeColor.opacity(0.3))
                                .rotationEffect(.degrees(-15))
                                .offset(x: geo.size.width * 0.5, y: -geo.size.height * 0.1)
                        }
                    }
                    .frame(height: 120)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(nodeColor.opacity(0.1), lineWidth: 1)
                    )
                    .clipped()
                }
            }
            .chiikawaCard()
            .padding(.bottom, 10)
        }
    }
}
