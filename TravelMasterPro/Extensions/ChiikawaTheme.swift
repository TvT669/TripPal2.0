//
//  ChiikawaTheme.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/27.
//

import SwiftUI
import UIKit

// MARK: - Chiikawa Color Palette
extension Color {
    // 吉伊卡哇 (Chiikawa) - 柔和的粉白
    static let chiikawaWhite = Color(hex: "FFFDF5") // 暖白背景
    static let chiikawaPink = Color(hex: "F8C3CD")  // 腮红粉
    
    // 小八猫 (Hachiware) - 清新的蓝
    static let chiikawaBlue = Color(hex: "A0D8EF")
    
    // 乌萨奇 (Usagi) - 活力的黄
    static let chiikawaYellow = Color(hex: "FDFD96")
    
    // 栗子馒头 - 暖棕色 (用于文字)
    static let chiikawaText = Color(hex: "594F4F")
    static let chiikawaSubText = Color(hex: "8E8080")
    
    // 辅助色
    static let chiikawaGray = Color(hex: "F0F0F0")
    static let chiikawaBorder = Color(hex: "E5E5E5")
}

// MARK: - Hex Color Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct ChiikawaCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(24) // 大圆角
            .shadow(color: Color.chiikawaText.opacity(0.05), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.chiikawaBorder, lineWidth: 1)
            )
    }
}

struct ChiikawaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundColor(.chiikawaText)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.chiikawaPink)
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
            .shadow(color: Color.chiikawaPink.opacity(0.4), radius: 5, x: 0, y: 3)
    }
}

struct ChiikawaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.chiikawaText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.chiikawaBlue.opacity(0.3))
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Extensions
extension View {
    func chiikawaCard() -> some View {
        modifier(ChiikawaCardStyle())
    }
    
    func chiikawaFont(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .rounded).weight(weight))
            .foregroundColor(.chiikawaText)
    }
    
    func chiikawaBackground() -> some View {
        self.background(Color.chiikawaWhite.ignoresSafeArea())
    }
}

// MARK: - Corner Radius Extension
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
