//
//  PhoenixApp.swift
//  PhoenixServer
//
//  Entry point - SwiftUI Application
//

import SwiftUI

@main
struct PhoenixApp: App {
    @StateObject private var serverManager = ServerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .frame(minWidth: 400, minHeight: 500)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
