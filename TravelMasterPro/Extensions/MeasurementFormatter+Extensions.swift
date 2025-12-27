//
//  MeasurementFormatter+Extensions.swift
//  NearMe
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/5/3.
//

import Foundation
 
extension MeasurementFormatter {
    
    static var distance: MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .naturalScale
        formatter.locale = Locale.current//跟随当前设备的语言和地区设置
        return formatter 
    }
}
