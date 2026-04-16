//
//  BedGridView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import SwiftUI
import SwiftData

struct BedGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var bed: Bed
    @State private var selectedPositionForAdd: PositionInfo?
    @State private var selectedPositionForEdit: PositionInfo?
    @State private var draggedPlant: Plant?
    @AppStorage("bedGridSortOrder") private var sortAscending = true
    
    var sortedRows: [BedRow] {
        bed.rows.sorted { $0.identifier < $1.identifier }
    }
    
    var positionRange: [Int] {
        let range = Array(1...bed.positionCount)
        return sortAscending ? range : range.reversed()
    }
    
    var body: some View {
        Group {
            if bed.isDeleted || bed.modelContext == nil {
                // Bed was deleted, show placeholder and dismiss
                ContentUnavailableView(
                    "Bed No Longer Exists",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This bed has been deleted or is no longer available")
                )
                .onAppear {
                    dismiss()
                }
            } else {
                gridContent
            }
        }
        .navigationTitle("\(bed.displayName) - Grid View")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
                        sortAscending.toggle()
                    }
                } label: {
                    Label(
                        sortAscending ? "Sort Descending" : "Sort Ascending",
                        systemImage: sortAscending ? "arrow.down.circle" : "arrow.up.circle"
                    )
                }
            }
        }
        .sheet(item: $selectedPositionForAdd) { positionInfo in
            AddPlantView(
                isPresented: Binding(
                    get: { selectedPositionForAdd != nil },
                    set: { if !$0 { selectedPositionForAdd = nil } }
                ),
                prefilledBed: bed,
                prefilledRow: positionInfo.rowIdentifier,
                prefilledPosition: positionInfo.position
            )
        }
        .sheet(item: $selectedPositionForEdit) { positionInfo in
            if let plant = positionInfo.plant {
                EditPlantView(
                    plant: plant,
                    isPresented: Binding(
                        get: { selectedPositionForEdit != nil },
                        set: { if !$0 { selectedPositionForEdit = nil } }
                    )
                )
            }
        }
    }
    
    private var gridContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    if sortedRows.isEmpty {
                        ContentUnavailableView(
                            "No Rows in Bed",
                            systemImage: "square.grid.3x3",
                            description: Text("Add rows to this bed to start planting")
                        )
                        .frame(maxWidth: .infinity, maxHeight: 300)
                    } else {
                        let cellWidth = calculateCellWidth(availableWidth: geometry.size.width)
                        
                        // Header row with row labels
                        HStack(spacing: 8) {
                            // Empty space for position labels
                            Text("")
                                .frame(width: 50)
                            
                            ForEach(sortedRows) { row in
                                Text(row.identifier)
                                    .font(.headline)
                                    .frame(width: cellWidth)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Position rows
                        ForEach(positionRange, id: \.self) { position in
                            HStack(spacing: 8) {
                                // Position label
                                Text("\(position)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                
                                ForEach(sortedRows) { row in
                                    PositionCell(
                                        bed: bed,
                                        row: row,
                                        position: position,
                                        plant: getPlant(row: row.identifier, position: position),
                                        cellWidth: cellWidth,
                                        draggedPlant: $draggedPlant
                                    ) {
                                        handlePositionTap(row: row, position: position)
                                    } onMove: { plant, toRow, toPosition in
                                        movePlant(plant: plant, toRow: toRow, toPosition: toPosition)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(minWidth: geometry.size.width)
                .padding(.vertical)
            }
        }
    }
    
    private func calculateCellWidth(availableWidth: CGFloat) -> CGFloat {
        let positionLabelWidth: CGFloat = 50
        let horizontalPadding: CGFloat = 32 // 16 on each side
        let spacing: CGFloat = 8
        let rowCount = CGFloat(sortedRows.count)
        
        let availableForCells = availableWidth - positionLabelWidth - horizontalPadding - (spacing * (rowCount + 1))
        let calculatedWidth = availableForCells / rowCount
        
        // Minimum cell width for usability, maximum for aesthetics
        return max(min(calculatedWidth, 150), 80)
    }
    
    private func getPlant(row: String, position: Int) -> Plant? {
        bed.plants.first { plant in
            plant.rowIdentifier == row && plant.position == position
        }
    }
    
    private func handlePositionTap(row: BedRow, position: Int) {
        if let plant = getPlant(row: row.identifier, position: position) {
            selectedPositionForEdit = PositionInfo(
                rowIdentifier: row.identifier,
                position: position,
                plant: plant
            )
        } else {
            selectedPositionForAdd = PositionInfo(
                rowIdentifier: row.identifier,
                position: position,
                plant: nil
            )
        }
    }
    
    private func movePlant(plant: Plant, toRow: String, toPosition: Int) {
        withAnimation {
            plant.rowIdentifier = toRow
            plant.position = toPosition
        }
    }
}

struct PositionInfo: Identifiable {
    let id = UUID()
    let rowIdentifier: String
    let position: Int
    let plant: Plant?
}

struct PositionCell: View {
    let bed: Bed
    let row: BedRow
    let position: Int
    let plant: Plant?
    let cellWidth: CGFloat
    @Binding var draggedPlant: Plant?
    let onTap: () -> Void
    let onMove: (Plant, String, Int) -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let plant = plant {
                    // Plant exists
                    if let firstPhoto = plant.photos.first {
                        // Show photo using thumbnail cache
                        ThumbnailImageView(
                            imageData: firstPhoto.imageData,
                            size: cellWidth,
                            cacheKey: firstPhoto.persistentModelID.hashValue.description
                        )
                        .frame(width: cellWidth, height: cellWidth)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let primaryColorHex = plant.primaryColor, let primaryColor = Color(hex: primaryColorHex) {
                        // Show color swatch
                        RoundedRectangle(cornerRadius: 8)
                            .fill(primaryColor)
                            .frame(width: cellWidth, height: cellWidth)
                            .overlay {
                                VStack {
                                    Image(systemName: "leaf.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                            }
                    } else {
                        // No photo or color
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.3))
                            .frame(width: cellWidth, height: cellWidth)
                            .overlay {
                                Image(systemName: "leaf")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    
                    Text(plant.name)
                        .font(.caption2)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: cellWidth)
                } else {
                    // Empty position
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.05))
                        )
                        .frame(width: cellWidth, height: cellWidth)
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("Empty")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    
                    // Placeholder text to match populated cell height
                    Text(" ")
                        .font(.caption2)
                        .lineLimit(2)
                        .frame(width: cellWidth)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(draggedPlant?.persistentModelID == plant?.persistentModelID ? 0.5 : 1.0)
        .onDrag {
            if let plant = plant {
                draggedPlant = plant
                let draggedPlantID = plant.persistentModelID
                // Fallback timeout: only reset if drag state is still set for this plant
                // This handles edge cases like dragging outside the window
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    // Only reset if still showing the same plant as dragged
                    // If drag completed normally, draggedPlant will already be nil
                    if draggedPlant?.persistentModelID == draggedPlantID {
                        draggedPlant = nil
                    }
                }
                return NSItemProvider(object: plant.name as NSString)
            }
            return NSItemProvider()
        }
        .dropDestination(for: String.self) { items, location in
            guard let currentDraggedPlant = draggedPlant,
                  plant == nil, // Only drop on empty positions
                  !items.isEmpty else {
                // Reset immediately on invalid drop
                draggedPlant = nil
                return false
            }
            
            // Reset drag state BEFORE moving to prevent flash
            draggedPlant = nil
            
            // Move the plant
            onMove(currentDraggedPlant, row.identifier, position)
            
            return true
        }
    }
}

#Preview("Bed Grid View") {
    let container = try! ModelContainer(
        for: Bed.self, BedRow.self, Plant.self, PlantPhoto.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let bed = Bed(name: "Bed 1", positionCount: 10)
    let rowA = BedRow(identifier: "A", bed: bed)
    let rowB = BedRow(identifier: "B", bed: bed)
    bed.rows = [rowA, rowB]
    
    let plant1 = Plant(name: "Dahlia 'Winkie Chevron'", primaryColor: "Pink", rowIdentifier: "A", position: 3, bed: bed)
    let plant2 = Plant(name: "Rose 'Peace'", primaryColor: "Yellow", rowIdentifier: "A", position: 5, bed: bed)
    let plant3 = Plant(name: "Tulip", primaryColor: "Red", rowIdentifier: "B", position: 2, bed: bed)
    
    bed.plants = [plant1, plant2, plant3]
    
    container.mainContext.insert(bed)
    container.mainContext.insert(plant1)
    container.mainContext.insert(plant2)
    container.mainContext.insert(plant3)
    
    return NavigationStack {
        BedGridView(bed: bed)
    }
    .modelContainer(container)
}
