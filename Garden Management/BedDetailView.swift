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
    @Bindable var bed: Bed
    @State private var showingAddRow = false
    @State private var isEditingBedName = false
    @State private var editedBedName = ""
    @State private var showingAddPlant = false
    @State private var showingDeleteAlert = false
    @State private var deleteAlertMessage = ""
    
    var sortedRows: [BedRow] {
        bed.rows.sorted { $0.identifier < $1.identifier }
    }
    
    var body: some View {
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
                
                NavigationLink {
                    BedGridView(bed: bed)
                } label: {
                    Label("View Grid Layout", systemImage: "square.grid.3x3")
                }
            }
            
            Section {
                ForEach(sortedRows) { row in
                    RowItemView(row: row, onDelete: { deleteRow(row) })
                }
                .onDelete(perform: deleteRows)
                
                if bed.rows.isEmpty {
                    Text("No rows yet")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            } header: {
                HStack {
                    Text("Rows")
                    Spacer()
                    Button {
                        showingAddRow = true
                    } label: {
                        Label("Add Row", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                    }
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
                }
            }
        }
        .navigationTitle(bed.name)
        .sheet(isPresented: $showingAddRow) {
            AddRowSheet(bed: bed, isPresented: $showingAddRow)
        }
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView(isPresented: $showingAddPlant)
        }
        .alert("Cannot Delete Row", isPresented: $showingDeleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteAlertMessage)
        }
    }
    
    private func deleteRow(_ row: BedRow) {
        let plantsInRow = bed.plants.filter { $0.rowIdentifier == row.identifier }
        
        if !plantsInRow.isEmpty {
            deleteAlertMessage = "This row contains \(plantsInRow.count) plant\(plantsInRow.count == 1 ? "" : "s"). Please remove all plants from the row before deleting it."
            showingDeleteAlert = true
            return
        }
        
        withAnimation {
            modelContext.delete(row)
        }
    }
    
    private func deleteRows(offsets: IndexSet) {
        let rowsToDelete = offsets.map { sortedRows[$0] }
        
        for row in rowsToDelete {
            let plantsInRow = bed.plants.filter { $0.rowIdentifier == row.identifier }
            
            if !plantsInRow.isEmpty {
                deleteAlertMessage = "Row \(row.identifier) contains \(plantsInRow.count) plant\(plantsInRow.count == 1 ? "" : "s"). Please remove all plants from the row before deleting it."
                showingDeleteAlert = true
                return
            }
        }
        
        withAnimation {
            for row in rowsToDelete {
                modelContext.delete(row)
            }
        }
    }
}

struct RowItemView: View {
    @Bindable var row: BedRow
    var onDelete: () -> Void
    @State private var isEditingPositionCount = false
    @State private var positionCountText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Row \(row.identifier)")
                    .font(.headline)
                Spacer()
#if os(iOS)
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
#endif
            }
            
            HStack {
                Text("Positions:")
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
                            row.positionCount = count
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
                    Text("\(row.positionCount)")
                        .fontWeight(.medium)
                    
                    Button("Edit") {
                        positionCountText = "\(row.positionCount)"
                        isEditingPositionCount = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddRowSheet: View {
    @Environment(\.modelContext) private var modelContext
    var bed: Bed
    @Binding var isPresented: Bool
    @State private var rowIdentifier = ""
    @State private var positionCount = "10"
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Row Identifier", text: $rowIdentifier)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
#endif
                    
                    TextField("Number of Positions", text: $positionCount)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                } header: {
                    Text("Row Details")
                } footer: {
                    Text("Row identifier (e.g., A, B, C) and number of positions in this row")
                }
            }
            .navigationTitle("Add Row")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRow()
                    }
                    .disabled(!isValid)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 250)
#endif
    }
    
    private var isValid: Bool {
        !rowIdentifier.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(positionCount) != nil &&
        Int(positionCount)! > 0
    }
    
    private func addRow() {
        guard let count = Int(positionCount) else { return }
        
        withAnimation {
            let row = BedRow(
                identifier: rowIdentifier.trimmingCharacters(in: .whitespaces).uppercased(),
                positionCount: count,
                bed: bed
            )
            modelContext.insert(row)
            bed.rows.append(row)
            isPresented = false
        }
    }
}

struct PlantInBedRowView: View {
    let plant: Plant
    
    var body: some View {
        HStack(spacing: 12) {
            if let firstPhoto = plant.photos.first {
                Image(data: firstPhoto.imageData)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
                
                if let primaryColor = plant.primaryColor {
                    Text(primaryColor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Bed Detail") {
    let container = try! ModelContainer(for: Bed.self, BedRow.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let bed = Bed(name: "Bed 1")
    let rowA = BedRow(identifier: "A", positionCount: 10, bed: bed)
    let rowB = BedRow(identifier: "B", positionCount: 8, bed: bed)
    bed.rows = [rowA, rowB]
    container.mainContext.insert(bed)
    
    return NavigationStack {
        BedDetailView(bed: bed)
    }
    .modelContainer(container)
}
