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
    @Bindable var bed: Bed
    @State private var selectedPositionForAdd: PositionInfo?
    @State private var selectedPositionForEdit: PositionInfo?
    @AppStorage("bedGridSortOrder") private var sortAscending = true
    
    var sortedRows: [BedRow] {
        bed.rows.sorted { $0.identifier < $1.identifier }
    }
    
    var maxPositions: Int {
        sortedRows.map { $0.positionCount }.max() ?? 0
    }
    
    var positionRange: [Int] {
        let range = Array(1...maxPositions)
        return sortAscending ? range : range.reversed()
    }
    
    var body: some View {
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
                                Text("Row \(row.identifier)")
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
                                    if position <= row.positionCount {
                                        PositionCell(
                                            bed: bed,
                                            row: row,
                                            position: position,
                                            plant: getPlant(row: row.identifier, position: position),
                                            cellWidth: cellWidth
                                        ) {
                                            handlePositionTap(row: row, position: position)
                                        }
                                    } else {
                                        // Empty placeholder for rows with fewer positions
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(width: cellWidth, height: cellWidth)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("\(bed.name) - Grid View")
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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let plant = plant {
                    // Plant exists
                    if let firstPhoto = plant.photos.first {
                        // Show photo
                        Image(data: firstPhoto.imageData)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cellWidth, height: cellWidth)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let primaryColor = plant.primaryColor {
                        // Show color swatch
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorFromString(primaryColor))
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
                    
                    Text("Pos \(position)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: cellWidth)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        let lowercased = colorName.lowercased()
        
        switch lowercased {
        case let str where str.contains("red"):
            return .red
        case let str where str.contains("pink"):
            return .pink
        case let str where str.contains("orange"):
            return .orange
        case let str where str.contains("yellow"):
            return .yellow
        case let str where str.contains("green"):
            return .green
        case let str where str.contains("blue"):
            return .blue
        case let str where str.contains("purple") || str.contains("violet"):
            return .purple
        case let str where str.contains("white"):
            return .white
        case let str where str.contains("black"):
            return .black
        case let str where str.contains("brown"):
            return .brown
        case let str where str.contains("gray") || str.contains("grey"):
            return .gray
        default:
            return .green
        }
    }
}

#Preview("Bed Grid View") {
    let container = try! ModelContainer(
        for: Bed.self, BedRow.self, Plant.self, PlantPhoto.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let bed = Bed(name: "Bed 1")
    let rowA = BedRow(identifier: "A", positionCount: 10, bed: bed)
    let rowB = BedRow(identifier: "B", positionCount: 8, bed: bed)
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
