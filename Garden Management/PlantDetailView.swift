//
//  PlantDetailView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import SwiftUI
import SwiftData
import PhotosUI

struct PlantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plant: Plant
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !plant.photos.isEmpty {
                    PhotoGalleryView(photos: plant.photos)
                        .frame(height: 300)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Section {
                        DetailRow(label: "Name", value: plant.name)
                        
                        if let primaryColor = plant.primaryColor {
                            HStack {
                                Text("Color:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 8) {
                                    if let color = Color(hex: primaryColor) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 24, height: 24)
                                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    }
                                    
                                    if let secondaryColorHex = plant.secondaryColor,
                                       let secondaryColor = Color(hex: secondaryColorHex) {
                                        Circle()
                                            .fill(secondaryColor)
                                            .frame(width: 24, height: 24)
                                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    }
                                }
                            }
                        }
                        
                        DetailRow(label: "Location", value: plant.locationDescription)
                        
                        DetailRow(
                            label: "Entered",
                            value: plant.enteredDate.formatted(date: .long, time: .omitted)
                        )
                        
                        if let notes = plant.notes {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes:")
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(plant.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            ToolbarItem {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlantView(plant: plant, isPresented: $showingEditSheet)
        }
        .alert("Delete Plant", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePlant()
            }
        } message: {
            Text("Are you sure you want to delete \(plant.name)? This cannot be undone.")
        }
    }
    
    private func deletePlant() {
        modelContext.delete(plant)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PhotoGalleryView: View {
    let photos: [PlantPhoto]
    @State private var selectedPhotoIndex = 0
    
    var body: some View {
        VStack {
#if os(iOS)
            TabView(selection: $selectedPhotoIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    Image(data: photos[index].imageData)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
#else
            // macOS: Simple horizontal scroll
            TabView(selection: $selectedPhotoIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    Image(data: photos[index].imageData)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
#endif
            
            if let caption = photos[selectedPhotoIndex].caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

struct EditPlantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bed.name) private var beds: [Bed]
    @Bindable var plant: Plant
    @Binding var isPresented: Bool
    
    @State private var plantName: String
    @State private var primaryColor: Color
    @State private var hasPrimaryColor: Bool
    @State private var secondaryColor: Color
    @State private var hasSecondaryColor: Bool
    @State private var selectedBed: Bed?
    @State private var rowIdentifier: String
    @State private var position: Int?
    @State private var notes: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataItems: [Data] = []
    @State private var showingCamera = false
    @State private var isInitialSetup = true
    
    init(plant: Plant, isPresented: Binding<Bool>) {
        self.plant = plant
        self._isPresented = isPresented
        self._plantName = State(initialValue: plant.name)
        
        // Initialize colors from hex strings
        if let hexColor = plant.primaryColor, let color = Color(hex: hexColor) {
            self._primaryColor = State(initialValue: color)
            self._hasPrimaryColor = State(initialValue: true)
        } else {
            self._primaryColor = State(initialValue: .red)
            self._hasPrimaryColor = State(initialValue: false)
        }
        
        if let hexColor = plant.secondaryColor, let color = Color(hex: hexColor) {
            self._secondaryColor = State(initialValue: color)
            self._hasSecondaryColor = State(initialValue: true)
        } else {
            self._secondaryColor = State(initialValue: .blue)
            self._hasSecondaryColor = State(initialValue: false)
        }
        
        self._selectedBed = State(initialValue: plant.bed)
        self._rowIdentifier = State(initialValue: plant.rowIdentifier)
        self._position = State(initialValue: plant.position)
        self._notes = State(initialValue: plant.notes ?? "")
        self._photoDataItems = State(initialValue: plant.photos.map { $0.imageData })
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
        
        // Get occupied positions in this row (excluding current plant)
        let occupiedPositions = bed.plants
            .filter { $0.rowIdentifier == rowIdentifier && $0.id != plant.id }
            .map { $0.position }
        
        // Filter out occupied positions, but always include current plant's position
        return allPositions.filter { pos in
            !occupiedPositions.contains(pos) || pos == plant.position
        }
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
                }
                
                Section {
                    Toggle("Primary Color", isOn: $hasPrimaryColor)
                    
                    if hasPrimaryColor {
                        ColorPicker("Color", selection: $primaryColor, supportsOpacity: false)
                        
                        Toggle("Secondary Color", isOn: $hasSecondaryColor)
                        
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
            .navigationTitle("Edit Plant")
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
                    Button("Save") {
                        savePlant()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photoDataItems.append(data)
                        }
                    }
                    selectedPhotos.removeAll()
                }
            }
            .onChange(of: selectedBed) { oldValue, newValue in
                // Reset row and position when bed changes (but not during initial setup)
                if !isInitialSetup && oldValue?.id != newValue?.id {
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
    
    private func savePlant() {
        guard let bed = selectedBed,
              let positionNum = position else { return }
        
        withAnimation {
            plant.name = plantName.trimmingCharacters(in: .whitespaces)
            plant.primaryColor = hasPrimaryColor ? primaryColor.toHex() : nil
            plant.secondaryColor = hasSecondaryColor ? secondaryColor.toHex() : nil
            plant.bed = bed
            plant.rowIdentifier = rowIdentifier
            plant.position = positionNum
            plant.notes = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
            
            // Handle photos - remove existing photos that are not in the new list
            let existingPhotoData = Set(plant.photos.map { $0.imageData })
            let newPhotoData = Set(photoDataItems)
            
            // Remove deleted photos
            for photo in plant.photos where !newPhotoData.contains(photo.imageData) {
                modelContext.delete(photo)
            }
            
            // Add new photos
            for data in photoDataItems where !existingPhotoData.contains(data) {
                let photo = PlantPhoto(imageData: data, plant: plant)
                modelContext.insert(photo)
                plant.photos.append(photo)
            }
            
            isPresented = false
        }
    }
}

#Preview("Plant Detail") {
    let container = try! ModelContainer(
        for: Plant.self, PlantPhoto.self, Bed.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let bed = Bed(name: "Bed 3")
    let plant = Plant(
        name: "Dahlia 'Winkie Chevron'",
        primaryColor: "Pink",
        rowIdentifier: "A",
        position: 10,
        bed: bed
    )
    
    container.mainContext.insert(bed)
    container.mainContext.insert(plant)
    
    return NavigationStack {
        PlantDetailView(plant: plant)
    }
    .modelContainer(container)
}
