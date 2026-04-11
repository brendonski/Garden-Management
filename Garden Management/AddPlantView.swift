//
//  AddPlantView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddPlantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bed.name) private var beds: [Bed]
    @Binding var isPresented: Bool
    
    var prefilledBed: Bed?
    var prefilledRow: String?
    var prefilledPosition: Int?
    
    @State private var plantName = ""
    @State private var primaryColor: Color = .red
    @State private var hasPrimaryColor = false
    @State private var secondaryColor: Color = .blue
    @State private var hasSecondaryColor = false
    @State private var selectedBed: Bed?
    @State private var rowIdentifier = ""
    @State private var position: Int?
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataItems: [Data] = []
    @State private var showingCamera = false
    @State private var isInitialSetup = true
    
    var availableRows: [BedRow] {
        selectedBed?.rows.sorted { $0.identifier < $1.identifier } ?? []
    }
    
    var selectedRow: BedRow? {
        availableRows.first { $0.identifier == rowIdentifier }
    }
    
    var availablePositions: [Int] {
        guard let bed = selectedBed else { return [] }
        let allPositions = Array(1...bed.positionCount)
        
        // Get occupied positions in this row
        let occupiedPositions = bed.plants
            .filter { $0.rowIdentifier == rowIdentifier }
            .map { $0.position }
        
        // Filter out occupied positions
        return allPositions.filter { !occupiedPositions.contains($0) }
    }
    
    init(isPresented: Binding<Bool>, prefilledBed: Bed? = nil, prefilledRow: String? = nil, prefilledPosition: Int? = nil) {
        self._isPresented = isPresented
        self.prefilledBed = prefilledBed
        self.prefilledRow = prefilledRow
        self.prefilledPosition = prefilledPosition
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Plant Name", text: $plantName)
#if os(iOS)
                        .textInputAutocapitalization(.words)
#endif
                } header: {
                    Text("Plant Details")
                } footer: {
                    Text("E.g., Dahlia \"Winkie Chevron\"")
                }
                
                Section {
                    Toggle("Add Primary Color", isOn: $hasPrimaryColor)
                    
                    if hasPrimaryColor {
                        ColorPicker("Color", selection: $primaryColor, supportsOpacity: false)
                        
                        Toggle("Add Secondary Color", isOn: $hasSecondaryColor)
                        
                        if hasSecondaryColor {
                            ColorPicker("Color", selection: $secondaryColor, supportsOpacity: false)
                        }
                    }
                } header: {
                    Text("Colors")
                }
                
                Section {
                    Picker("Bed", selection: $selectedBed) {
                        Text("Select a bed").tag(nil as Bed?)
                        ForEach(beds) { bed in
                            Text(bed.name).tag(bed as Bed?)
                        }
                    }
                    
                    if !availableRows.isEmpty {
                        Picker("Row", selection: $rowIdentifier) {
                            Text("Select a row").tag("")
                            ForEach(availableRows) { row in
                                Text("Row \(row.identifier)").tag(row.identifier)
                            }
                        }
                        
                        if !availablePositions.isEmpty {
                            Picker("Position", selection: $position) {
                                Text("Select a position").tag(nil as Int?)
                                ForEach(availablePositions, id: \.self) { pos in
                                    Text("\(pos)").tag(pos as Int?)
                                }
                            }
                        }
                    } else if selectedBed != nil {
                        Text("This bed has no rows yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                } header: {
                    Text("Location")
                }
                
                Section {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Add Photos from Library", systemImage: "photo.on.rectangle.angled")
                    }
                    
#if os(iOS)
                    CameraButton(showingCamera: $showingCamera, capturedImages: $photoDataItems)
#endif
                    
                    if !photoDataItems.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photoDataItems.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(data: photoDataItems[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button {
                                            photoDataItems.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Photos")
                }
                
                Section {
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Add Plant")
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
                        addPlant()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    photoDataItems.removeAll()
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photoDataItems.append(data)
                        }
                    }
                }
            }
            .onChange(of: selectedBed) { oldValue, newValue in
                // Reset row and position when bed changes (but not during initial setup)
                if !isInitialSetup {
                    rowIdentifier = ""
                    position = nil
                }
            }
            .onChange(of: rowIdentifier) { oldValue, newValue in
                // Reset position when row changes (but not during initial setup)
                if !isInitialSetup && oldValue != newValue {
                    position = nil
                }
            }
            .onAppear {
                if let bed = prefilledBed {
                    selectedBed = bed
                }
                if let row = prefilledRow {
                    rowIdentifier = row
                }
                if let pos = prefilledPosition {
                    position = pos
                }
                // Allow onChange handlers to work after initial setup
                DispatchQueue.main.async {
                    isInitialSetup = false
                }
            }
#if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(isPresented: $showingCamera, capturedImages: $photoDataItems)
                    .ignoresSafeArea()
            }
#endif
        }
#if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
#endif
    }
    
    private var isValid: Bool {
        !plantName.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedBed != nil &&
        !rowIdentifier.isEmpty &&
        position != nil
    }
    
    private func addPlant() {
        guard let bed = selectedBed,
              let positionNum = position else { return }
        
        withAnimation {
            let plant = Plant(
                name: plantName.trimmingCharacters(in: .whitespaces),
                primaryColor: hasPrimaryColor ? primaryColor.toHex() : nil,
                secondaryColor: hasSecondaryColor ? secondaryColor.toHex() : nil,
                rowIdentifier: rowIdentifier,
                position: positionNum,
                bed: bed,
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
            )
            
            modelContext.insert(plant)
            bed.plants.append(plant)
            
            for photoData in photoDataItems {
                let photo = PlantPhoto(imageData: photoData, plant: plant)
                modelContext.insert(photo)
                plant.photos.append(photo)
            }
            
            isPresented = false
        }
    }
}

extension Color {
    func toHex() -> String {
#if os(iOS)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
#elseif os(macOS)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
#endif
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { return nil }
        
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

#Preview("Add Plant") {
    let container = try! ModelContainer(
        for: Plant.self, Bed.self, BedRow.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let bed = Bed(name: "Bed 1", positionCount: 10)
    let rowA = BedRow(identifier: "A", bed: bed)
    bed.rows = [rowA]
    container.mainContext.insert(bed)
    
    return AddPlantView(isPresented: .constant(true))
        .modelContainer(container)
}
