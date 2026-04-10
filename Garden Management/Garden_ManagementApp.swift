//
//  Garden_ManagementApp.swift
//  Garden Management
//
//  Created by Brendon Kelly on 6/4/2026.
//

import SwiftUI
import SwiftData

@main
struct Garden_ManagementApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bed.self,
            BedRow.self,
            Plant.self,
            PlantPhoto.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct MainTabView: View {
    var body: some View {
#if os(iOS)
        TabView {
            BedListView()
                .tabItem {
                    Label("Beds", systemImage: "square.grid.3x3")
                }
            
            PlantListView()
                .tabItem {
                    Label("Plants", systemImage: "leaf")
                }
        }
#else
        // For macOS, use sidebar navigation
        NavigationSplitView {
            List {
                NavigationLink {
                    BedListView()
                } label: {
                    Label("Beds", systemImage: "square.grid.3x3")
                }
                
                NavigationLink {
                    PlantListView()
                } label: {
                    Label("Plants", systemImage: "leaf")
                }
            }
            .navigationTitle("Garden Management")
        } detail: {
            Text("Select a section")
                .foregroundStyle(.secondary)
        }
#endif
    }
}
