//
//  PlantListView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import SwiftUI
import SwiftData

struct PlantListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plant.name) private var plants: [Plant]
    @State private var showingAddPlant = false
    @State private var searchText = ""
    @State private var selectedBedFilter: Bed?
    
    var filteredPlants: [Plant] {
        var result = plants
        
        if !searchText.isEmpty {
            result = result.filter { plant in
                plant.name.localizedCaseInsensitiveContains(searchText) ||
                plant.rowIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let selectedBed = selectedBedFilter {
            result = result.filter { $0.bed?.persistentModelID == selectedBed.persistentModelID }
        }
        
        return result
    }
    
    var body: some View {
        NavigationViewWrapper {
            List {
                ForEach(filteredPlants) { plant in
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        PlantRowView(plant: plant)
                    }
                }
                .onDelete(perform: deletePlants)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 250)
#endif
            .navigationTitle("Plants")
            .searchable(text: $searchText, prompt: "Search plants")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: { showingAddPlant = true }) {
                        Label("Add Plant", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlant) {
                AddPlantView(isPresented: $showingAddPlant)
            }
            .overlay {
                if plants.isEmpty {
                    ContentUnavailableView(
                        "No Plants Yet",
                        systemImage: "leaf",
                        description: Text("Add your first plant to get started")
                    )
                } else if filteredPlants.isEmpty {
                    ContentUnavailableView.search
                }
            }
        }
    }
    
    private func deletePlants(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredPlants[index])
            }
        }
    }
}

struct PlantRowView: View {
    let plant: Plant
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let firstPhoto = plant.photos.first {
                Image(data: firstPhoto.imageData)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "leaf")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                
                if let primaryColor = plant.primaryColor {
                    HStack(spacing: 4) {
                        Text(primaryColor)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let secondaryColor = plant.secondaryColor {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(secondaryColor)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Text(plant.locationDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

fileprivate struct NavigationViewWrapper<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
#if os(macOS)
        NavigationSplitView {
            content()
        } detail: {
            Text("Select a plant")
                .foregroundStyle(.secondary)
        }
#else
        NavigationStack {
            content()
        }
#endif
    }
}

extension Image {
    init(data: Data) {
#if os(macOS)
        if let nsImage = NSImage(data: data) {
            self.init(nsImage: nsImage)
        } else {
            self.init(systemName: "photo")
        }
#else
        if let uiImage = UIImage(data: data) {
            self.init(uiImage: uiImage)
        } else {
            self.init(systemName: "photo")
        }
#endif
    }
}

#Preview("Plant List") {
    let container = try! ModelContainer(
        for: Plant.self, PlantPhoto.self, Bed.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let bed = Bed(name: "Bed 1")
    let plant1 = Plant(name: "Dahlia 'Winkie Chevron'", primaryColor: "Pink", rowIdentifier: "A", position: 1, bed: bed)
    let plant2 = Plant(name: "Rose 'Peace'", primaryColor: "Yellow", secondaryColor: "Pink", rowIdentifier: "B", position: 5, bed: bed)
    
    container.mainContext.insert(bed)
    container.mainContext.insert(plant1)
    container.mainContext.insert(plant2)
    
    return PlantListView()
        .modelContainer(container)
}
