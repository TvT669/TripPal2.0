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
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 左侧时间轴线
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 5)
            
            // 右侧卡片内容
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(node.name)
                        .font(.headline)
                    Spacer()
                    if let time = node.startTime {
                        Text(time, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(node.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 可以在这里加图片占位符
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))
                    )
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.bottom, 15)
        }
    }
}
