//
//  BedDetailView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 6/4/2026.
//

import SwiftUI
import SwiftData

struct BedDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var bed: Bed
    @State private var isEditingBedName = false
    @State private var editedBedName = ""
    @State private var showingAddPlant = false
    
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
                bedDetailContent
            }
        }
    }
    
    private var bedDetailContent: some View {
        List {
            Section {
                HStack {
                    Text("Bed Name")
                        .foregroundStyle(.secondary)
                    
                    if isEditingBedName {
                        TextField("Bed Name", text: $editedBedName)
                            .textFieldStyle(.roundedBorder)
#if os(iOS)
                            .textInputAutocapitalization(.words)
#endif
                        
                        Button("Save") {
                            if !editedBedName.trimmingCharacters(in: .whitespaces).isEmpty {
                                bed.name = editedBedName.trimmingCharacters(in: .whitespaces)
                                isEditingBedName = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Cancel") {
                            isEditingBedName = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Spacer()
                        Text(bed.name)
                            .fontWeight(.medium)
                        
                        Button("Edit") {
                            editedBedName = bed.name
                            isEditingBedName = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                BedPositionCountRow(bed: bed)
                
                NavigationLink {
                    BedGridView(bed: bed)
                } label: {
                    Label("View Grid Layout", systemImage: "square.grid.3x3")
                }
            }
            
            Section {
                BedRowCountRow(bed: bed)
            } header: {
                Text("Rows")
            } footer: {
                if bed.rows.isEmpty {
                    Text("Add at least one row before adding plants")
                        .font(.caption)
                } else {
                    Text("Rows: \(bed.rows.sorted { $0.identifier < $1.identifier }.map { $0.identifier }.joined(separator: ", "))")
                        .font(.caption)
                }
            }
            
            Section {
                if bed.plants.isEmpty {
                    Text("No plants yet")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(bed.plants.sorted(by: { 
                        if $0.rowIdentifier == $1.rowIdentifier {
                            return $0.position < $1.position
                        }
                        return $0.rowIdentifier < $1.rowIdentifier
                    })) { plant in
                        NavigationLink {
                            PlantDetailView(plant: plant)
                        } label: {
                            PlantInBedRowView(plant: plant)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Plants")
                    Spacer()
                    Button {
                        showingAddPlant = true
                    } label: {
                        Label("Add Plant", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(bed.rows.isEmpty)
                }
            } footer: {
                if bed.rows.isEmpty {
                    Text("Add at least one row before adding plants")
                        .font(.caption)
                }
            }
        }
        .navigationTitle(bed.displayName)
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView(isPresented: $showingAddPlant, prefilledBed: bed)
        }
    }
}

struct BedRowCountRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var bed: Bed
    @State private var isEditingRowCount = false
    @State private var rowCountText = ""
    @State private var showingDeleteAlert = false
    @State private var deleteAlertMessage = ""
    
    var body: some View {
        HStack {
            Text("Number of Rows")
                .foregroundStyle(.secondary)
            
            if isEditingRowCount {
                TextField("Count", text: $rowCountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                
                Button("Save") {
                    if let count = Int(rowCountText), count >= 0 {
                        updateRowCount(to: count)
                        isEditingRowCount = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Cancel") {
                    isEditingRowCount = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Spacer()
                Text("\(bed.rows.count)")
                    .fontWeight(.medium)
                
                Button("Edit") {
                    rowCountText = "\(bed.rows.count)"
                    isEditingRowCount = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .alert("Cannot Remove Rows", isPresented: $showingDeleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteAlertMessage)
        }
    }
    
    private func updateRowCount(to newCount: Int) {
        let currentCount = bed.rows.count
        
        if newCount == currentCount {
            return
        }
        
        if newCount > currentCount {
            // Add new rows
            let sortedRows = bed.rows.sorted { $0.identifier < $1.identifier }
            let lastIdentifier = sortedRows.last?.identifier ?? ""
            let startIndex = getNextLetterIndex(after: lastIdentifier)
            
            withAnimation {
                for i in 0..<(newCount - currentCount) {
                    let identifier = getLetterForIndex(startIndex + i)
                    let row = BedRow(identifier: identifier, bed: bed)
                    modelContext.insert(row)
                    bed.rows.append(row)
                }
            }
        } else {
            // Remove rows (from the end)
            let sortedRows = bed.rows.sorted { $0.identifier < $1.identifier }
            let rowsToRemove = sortedRows.suffix(currentCount - newCount)
            
            // Check if any rows to be removed have plants
            for row in rowsToRemove {
                let plantsInRow = bed.plants.filter { $0.rowIdentifier == row.identifier }
                if !plantsInRow.isEmpty {
                    deleteAlertMessage = "Cannot reduce row count. Row \(row.identifier) contains \(plantsInRow.count) plant\(plantsInRow.count == 1 ? "" : "s"). Please remove all plants from rows \(rowsToRemove.map { $0.identifier }.joined(separator: ", ")) first."
                    showingDeleteAlert = true
                    return
                }
            }
            
            // Safe to delete
            withAnimation {
                for row in rowsToRemove {
                    modelContext.delete(row)
                }
            }
        }
    }
    
    private func getNextLetterIndex(after identifier: String) -> Int {
        if identifier.isEmpty {
            return 0
        }
        // Convert letter to index (A=0, B=1, etc.)
        guard let firstChar = identifier.first,
              let asciiValue = firstChar.asciiValue else {
            return 0
        }
        return Int(asciiValue - Character("A").asciiValue!) + 1
    }
    
    private func getLetterForIndex(_ index: Int) -> String {
        // Convert index to letter (0=A, 1=B, etc.)
        // For now, support A-Z (26 letters)
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        if index < letters.count {
            let letterIndex = letters.index(letters.startIndex, offsetBy: index)
            return String(letters[letterIndex])
        }
        // If we need more than 26, use AA, AB, etc.
        let firstLetter = index / 26
        let secondLetter = index % 26
        if firstLetter > 0 {
            return getLetterForIndex(firstLetter - 1) + getLetterForIndex(secondLetter)
        }
        return String(letters[letters.index(letters.startIndex, offsetBy: secondLetter)])
    }
}

struct BedPositionCountRow: View {
    @Bindable var bed: Bed
    @State private var isEditingPositionCount = false
    @State private var positionCountText = ""
    
    var body: some View {
        HStack {
            Text("Number of positions per Row")
                .foregroundStyle(.secondary)
            
            if isEditingPositionCount {
                TextField("Count", text: $positionCountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                
                Button("Save") {
                    if let count = Int(positionCountText), count > 0 {
                        bed.positionCount = count
                        isEditingPositionCount = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Cancel") {
                    isEditingPositionCount = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Spacer()
                Text("\(bed.positionCount)")
                    .fontWeight(.medium)
                
                Button("Edit") {
                    positionCountText = "\(bed.positionCount)"
                    isEditingPositionCount = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct PlantInBedRowView: View {
    let plant: Plant
    
    var body: some View {
        HStack(spacing: 12) {
            if let firstPhoto = plant.photos.first {
                ThumbnailImageView(
                    imageData: firstPhoto.imageData,
                    size: 50,
                    cacheKey: firstPhoto.persistentModelID.hashValue.description
                )
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if let primaryColorHex = plant.primaryColor, let primaryColor = Color(hex: primaryColorHex) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(primaryColor)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "leaf")
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "leaf")
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.body)
                
                Text("Row \(plant.rowIdentifier), Position \(plant.position)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Bed Detail") {
    let container = try! ModelContainer(for: Bed.self, BedRow.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let bed = Bed(name: "Bed 1", positionCount: 10)
    let rowA = BedRow(identifier: "A", bed: bed)
    let rowB = BedRow(identifier: "B", bed: bed)
    bed.rows = [rowA, rowB]
    container.mainContext.insert(bed)
    
    return NavigationStack {
        BedDetailView(bed: bed)
    }
    .modelContainer(container)
}
