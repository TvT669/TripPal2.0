//
//  PlaceConfirmationView.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import SwiftUI

struct PlaceConfirmationView: View {
    @Binding var parsedPlaces: [ParsedPlace]
    @Environment(\.dismiss) var dismiss
    var onConfirm: ([ParsedPlace]) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部提示
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("AI 识别到 \(parsedPlaces.count) 个地点，请核对")
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                
                // 地点列表
                List {
                    ForEach($parsedPlaces) { $place in
                        HStack {
                            // 左侧图片占位
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.gray)
                                )
                            
                            VStack(alignment: .leading) {
                                Text(place.name)
                                    .font(.headline)
                                Text("原文: " + place.originalText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // 勾选按钮
                            Button(action: { place.isSelected.toggle() }) {
                                Image(systemName: place.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(place.isSelected ? .blue : .gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                
                // 底部操作栏
                VStack(spacing: 12) {
                    Button(action: {
                        let selected = parsedPlaces.filter { $0.isSelected }
                        onConfirm(selected)
                        dismiss()
                    }) {
                        HStack {
                            Text("添加到行程")
                                .bold()
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(radius: 5)
            }
            .navigationTitle("确认地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
