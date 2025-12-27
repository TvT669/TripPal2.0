//
//  TripStore.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import Foundation

class TripStore: ObservableObject {
    @Published var plans: [TripPlan] = []
    @Published var customRoutes: [CustomRoute] = []
    
    private let saveKey = "SavedTripPlans"
    private let routesSaveKey = "SavedCustomRoutes"
    
    init() {
        loadPlans()
        loadRoutes()
    }
    
    func addPlan(_ plan: TripPlan) {
        plans.insert(plan, at: 0)
        savePlans()
    }
    
    func deletePlan(at offsets: IndexSet) {
        plans.remove(atOffsets: offsets)
        savePlans()
    }
    
    func addRoute(_ route: CustomRoute) {
        customRoutes.insert(route, at: 0)
        saveRoutes()
    }
    
    func updateRoute(_ route: CustomRoute) {
        if let index = customRoutes.firstIndex(where: { $0.id == route.id }) {
            customRoutes[index] = route
            saveRoutes()
        } else {
            addRoute(route)
        }
    }
    
    func deleteRoute(at offsets: IndexSet) {
        customRoutes.remove(atOffsets: offsets)
        saveRoutes()
    }
    
    private func savePlans() {
        if let encoded = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func saveRoutes() {
        if let encoded = try? JSONEncoder().encode(customRoutes) {
            UserDefaults.standard.set(encoded, forKey: routesSaveKey)
        }
    }
    
    private func loadPlans() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([TripPlan].self, from: data) {
            plans = decoded
        }
    }
    
    private func loadRoutes() {
        if let data = UserDefaults.standard.data(forKey: routesSaveKey),
           let decoded = try? JSONDecoder().decode([CustomRoute].self, from: data) {
            customRoutes = decoded
        }
    }
}
