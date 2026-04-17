//
//  AddPlantView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import SwiftUI
import SwiftData
import PhotosUI
import Photos

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
    @State private var capturedPhotos: [CapturedPhoto] = []
    @State private var showingCamera = false
    @State private var isInitialSetup = true
    @State private var showingPhotoSelector = false
    @State private var showingColorPicker = false
    @State private var extractedColors: [DominantColor] = []
    @State private var selectedPhotoForColorPicker: Data? = nil
    @State private var colorPickerTarget: ColorTarget = .primary
    @State private var showValidationErrors = false
    @FocusState private var focusedField: Field?
    
    enum ColorTarget {
        case primary
        case secondary
    }
    
    enum Field: Hashable {
        case name
        case bed
        case row
        case position
    }
    
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
                        .focused($focusedField, equals: .name)
                    
                    if showValidationErrors && plantName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Plant name is required")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Plant Details")
                } footer: {
                    if !showValidationErrors || !plantName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("E.g., Dahlia \"Winkie Chevron\"")
                    }
                }
                
                Section {
                    Picker("Bed", selection: $selectedBed) {
                        Text("Select a bed").tag(nil as Bed?)
                        ForEach(beds) { bed in
                            Text(bed.name).tag(bed as Bed?)
                        }
                    }
                    .focused($focusedField, equals: .bed)
                    
                    if showValidationErrors && selectedBed == nil {
                        Text("Please select a bed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    if !availableRows.isEmpty {
                        Picker("Row", selection: $rowIdentifier) {
                            Text("Select a row").tag("")
                            ForEach(availableRows) { row in
                                Text("Row \(row.identifier)").tag(row.identifier)
                            }
                        }
                        .focused($focusedField, equals: .row)
                        
                        if showValidationErrors && rowIdentifier.isEmpty {
                            Text("Please select a row")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                        if !availablePositions.isEmpty {
                            Picker("Position", selection: $position) {
                                Text("Select a position").tag(nil as Int?)
                                ForEach(availablePositions, id: \.self) { pos in
                                    Text("\(pos)").tag(pos as Int?)
                                }
                            }
                            .focused($focusedField, equals: .position)
                            
                            if showValidationErrors && position == nil {
                                Text("Please select a position")
                                    .font(.caption)
                                    .foregroundStyle(.red)
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
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Add Photos from Library", systemImage: "photo.on.rectangle.angled")
                    }
                    
#if os(iOS)
                    CameraButton(showingCamera: $showingCamera, capturedPhotos: $capturedPhotos)
#endif
                    
                    if !capturedPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(capturedPhotos.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(data: capturedPhotos[index].imageData)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button {
                                            capturedPhotos.remove(at: index)
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
                    Toggle("Add Primary Color", isOn: $hasPrimaryColor)
                    
                    if hasPrimaryColor {
                        ColorPicker("Color", selection: $primaryColor, supportsOpacity: false)
                        
                        Toggle("Add Secondary Color", isOn: $hasSecondaryColor)
                        
                        if hasSecondaryColor {
                            ColorPicker("Color", selection: $secondaryColor, supportsOpacity: false)
                        }
                    }
                    
                    if !capturedPhotos.isEmpty {
                        Button {
                            colorPickerTarget = .primary
                            extractedColors = [] // Reset colors
                            showingColorPicker = true // Show sheet immediately with loading state
                            if capturedPhotos.count == 1 {
                                Task {
                                    let colors = await Task.detached(priority: .userInitiated) {
                                        ColorExtractor.extractDominantColors(from: capturedPhotos[0].imageData, count: 20)
                                    }.value
                                    extractedColors = colors
                                }
                            } else {
                                showingColorPicker = false
                                showingPhotoSelector = true
                            }
                        } label: {
                            Label("Pick Color from Photo", systemImage: "eyedropper")
                        }
                    }
                } header: {
                    Text("Colors")
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
                        if !isValid {
                            showValidationErrors = true
                            focusFirstInvalidField()
                        } else {
                            addPlant()
                        }
                    }
                }
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    for item in newValue {
                        // Load image data
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            // Get or create asset identifier (avoids duplicates)
                            let assetId = await PhotoLibraryHelper.getOrCreateAssetIdentifier(for: data)
                            capturedPhotos.append(CapturedPhoto(imageData: data, assetIdentifier: assetId))
                        }
                    }
                    // Clear selection after processing
                    selectedPhotos = []
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
            .sheet(isPresented: $showingPhotoSelector) {
                PhotoSelectionSheet(
                    photos: capturedPhotos.map { $0.imageData },
                    onSelect: { photoData in
                        selectedPhotoForColorPicker = photoData
                        extractedColors = [] // Reset colors
                        showingColorPicker = true // Show sheet immediately with loading state
                        Task { @MainActor in
                            let colors = ColorExtractor.extractDominantColors(from: photoData, count: 20)
                            extractedColors = colors
                        }
                    },
                    isPresented: $showingPhotoSelector
                )
            }
            .sheet(isPresented: $showingColorPicker) {
                if !extractedColors.isEmpty {
                    ColorSelectionSheet(
                        colors: extractedColors,
                        photoData: selectedPhotoForColorPicker,
                        onSelect: { color, hexString in
                            if colorPickerTarget == .primary {
                                primaryColor = color
                                hasPrimaryColor = true
                            } else {
                                secondaryColor = color
                                hasSecondaryColor = true
                            }
                        },
                        isPresented: $showingColorPicker
                    )
                } else {
                    NavigationStack {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Extracting colors...")
                                .padding(.top)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .navigationTitle("Pick Color from Photo")
#if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
#endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingColorPicker = false
                                }
                            }
                        }
                    }
                }
            }
#if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(isPresented: $showingCamera, capturedPhotos: $capturedPhotos)
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
    
    private func focusFirstInvalidField() {
        if plantName.trimmingCharacters(in: .whitespaces).isEmpty {
            focusedField = .name
        } else if selectedBed == nil {
            focusedField = .bed
        } else if rowIdentifier.isEmpty {
            focusedField = .row
        } else if position == nil {
            focusedField = .position
        }
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
            
            for photo in capturedPhotos {
                let plantPhoto = PlantPhoto(
                    imageData: photo.imageData,
                    assetIdentifier: photo.assetIdentifier,
                    plant: plant
                )
                modelContext.insert(plantPhoto)
                plant.photos.append(plantPhoto)
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
