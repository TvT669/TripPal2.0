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
                
                // 图片占位符
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.chiikawaWhite)
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(nodeColor.opacity(0.3))
                            Text("暂无图片")
                                .chiikawaFont(.caption)
                                .foregroundColor(nodeColor.opacity(0.3))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(nodeColor.opacity(0.1), lineWidth: 1)
                    )
            }
            .chiikawaCard()
            .padding(.bottom, 10)
        }
    }
}
