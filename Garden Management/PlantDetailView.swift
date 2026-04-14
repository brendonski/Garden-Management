//
//  PlantDetailView.swift (Simplified)
//  Garden Management
//
//  Simplified version to avoid Swift compiler timeout issues
//

import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct PlantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let plant: Plant
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !plant.photos.isEmpty {
                    PhotoGalleryView(photos: plant.photos)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    detailsSection
                    locationSection
                    if let notes = plant.notes {
                        notesSection(notes: notes)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(plant.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
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
            Text("Are you sure you want to delete \(plant.name)? This action cannot be undone.")
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Name", value: plant.name)
                if let primaryColor = plant.primaryColor, let color = Color(hex: primaryColor) {
                    colorRow(label: "Primary Color", color: color)
                }
                if let secondaryColor = plant.secondaryColor, let color = Color(hex: secondaryColor) {
                    colorRow(label: "Secondary Color", color: color)
                }
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Location", value: plant.locationDescription)
                DetailRow(label: "Entered", value: plant.enteredDate.formatted(date: .long, time: .omitted))
            }
        }
    }
    
    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes").font(.headline)
            Text(notes).font(.body)
        }
    }
    
    private func colorRow(label: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }
    
    private func deletePlant() {
        withAnimation {
            modelContext.delete(plant)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct PhotoGalleryView: View {
    let photos: [PlantPhoto]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(photos) { photo in
                    photoView(photo: photo)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func photoView(photo: PlantPhoto) -> some View {
        Image(data: photo.imageData)
            .resizable()
            .scaledToFill()
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EditPlantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bed.name) private var beds: [Bed]
    @Binding var isPresented: Bool
    let plant: Plant
    
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
    @State private var photoItems: [PhotoItem] = []  // Changed from photoDataItems
    @State private var showingCamera = false
    @State private var capturedPhotos: [CapturedPhoto] = []
    
    // Helper struct to track photo data and asset identifier
    struct PhotoItem: Identifiable {
        let id = UUID()
        let imageData: Data
        let assetIdentifier: String?
    }
    
    init(plant: Plant, isPresented: Binding<Bool>) {
        self.plant = plant
        self._isPresented = isPresented
        self._plantName = State(initialValue: plant.name)
        
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
        self._photoItems = State(initialValue: plant.photos.map { 
            PhotoItem(imageData: $0.imageData, assetIdentifier: $0.assetIdentifier)
        })
    }
    
    private var availableRows: [BedRow] {
        selectedBed?.rows.sorted { $0.identifier < $1.identifier } ?? []
    }
    
    private var availablePositions: [Int] {
        guard let bed = selectedBed else { return [] }
        let allPositions = Array(1...bed.positionCount)
        let occupiedPositions = bed.plants
            .filter { $0.rowIdentifier == rowIdentifier && $0.id != plant.id }
            .map { $0.position }
        return allPositions.filter { !occupiedPositions.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Edit Plant")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { savePlant() }
                            .disabled(plantName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .onChange(of: selectedPhotos) { _, newValue in
                    handleSelectedPhotos(newValue)
                }
                .onChange(of: capturedPhotos) { _, newValue in
                    handleCapturedPhotos(newValue)
                }
                #if os(iOS)
                .fullScreenCover(isPresented: $showingCamera) {
                    CameraView(isPresented: $showingCamera, capturedPhotos: $capturedPhotos)
                }
                #endif
        }
    }
    
    private var formContent: some View {
        Form {
            nameSection
            locationSection
            photoSection
            colorSection
            notesSection
        }
    }
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                // Get asset identifier if available
                var assetIdentifier: String?
                if let identifier = item.itemIdentifier {
                    // PhotosPickerItem identifier can be used with PHAsset
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        assetIdentifier = asset.localIdentifier
                    }
                }
                
                // Load image data
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoItems.append(PhotoItem(imageData: data, assetIdentifier: assetIdentifier))
                }
            }
            selectedPhotos = []
        }
    }
    
    private func handleCapturedPhotos(_ photos: [CapturedPhoto]) {
        for photo in photos {
            if !photoItems.contains(where: { $0.imageData == photo.imageData }) {
                photoItems.append(PhotoItem(imageData: photo.imageData, assetIdentifier: photo.assetIdentifier))
            }
        }
        capturedPhotos = []
    }
    
    private var nameSection: some View {
        Section("Plant Details") {
            TextField("Plant Name", text: $plantName)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
        }
    }
    
    private var locationSection: some View {
        Section("Location") {
            bedPickerView
            if !availableRows.isEmpty {
                rowPickerView
                if !availablePositions.isEmpty {
                    positionPickerView
                }
            }
        }
    }
    
    private var bedPickerView: some View {
        Picker("Bed", selection: $selectedBed) {
            Text("Select a bed").tag(Optional<Bed>.none)
            ForEach(beds) { bed in
                Text(bed.name).tag(Optional.some(bed))
            }
        }
    }
    
    private var rowPickerView: some View {
        Picker("Row", selection: $rowIdentifier) {
            Text("Select a row").tag("")
            ForEach(availableRows) { row in
                let label = "Row \(row.identifier)"
                Text(label).tag(row.identifier)
            }
        }
    }
    
    private var positionPickerView: some View {
        Picker("Position", selection: $position) {
            Text("Select a position").tag(Optional<Int>.none)
            ForEach(availablePositions, id: \.self) { pos in
                Text("\(pos)").tag(Optional.some(pos))
            }
        }
    }
    
    private var photoSection: some View {
        Section("Photos") {
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                Label("Add Photos from Library", systemImage: "photo.on.rectangle.angled")
            }
            #if os(iOS)
            CameraButton(showingCamera: $showingCamera, capturedPhotos: $capturedPhotos)
            #endif
            if !photoItems.isEmpty {
                photoScrollView
            }
        }
    }
    
    private var photoScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(photoItems) { item in
                    photoThumbnail(for: item)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func photoThumbnail(for item: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            imageView(data: item.imageData)
            deleteButton(for: item)
        }
    }
    
    private func deleteButton(for item: PhotoItem) -> some View {
        Button {
            photoItems.removeAll { $0.id == item.id }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, .red)
                .font(.title3)
        }
        .padding(4)
    }
    
    private func imageView(data: Data) -> some View {
        Group {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #endif
        }
    }
    
    private var colorSection: some View {
        Section("Colors") {
            Toggle("Add Primary Color", isOn: $hasPrimaryColor)
            if hasPrimaryColor {
                ColorPicker("Color", selection: $primaryColor, supportsOpacity: false)
                Toggle("Add Secondary Color", isOn: $hasSecondaryColor)
                if hasSecondaryColor {
                    ColorPicker("Color", selection: $secondaryColor, supportsOpacity: false)
                }
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes (Optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private func savePlant() {
        withAnimation {
            plant.name = plantName.trimmingCharacters(in: .whitespaces)
            plant.primaryColor = hasPrimaryColor ? primaryColor.toHex() : nil
            plant.secondaryColor = hasSecondaryColor ? secondaryColor.toHex() : nil
            plant.bed = selectedBed
            plant.rowIdentifier = rowIdentifier
            plant.position = position ?? plant.position
            plant.notes = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
            
            // Remove photos that are no longer in the photo items list
            let newPhotoDataSet = Set(photoItems.map { $0.imageData })
            for photo in plant.photos where !newPhotoDataSet.contains(photo.imageData) {
                modelContext.delete(photo)
            }
            
            // Add new photos
            let existingPhotoDataSet = Set(plant.photos.map { $0.imageData })
            for item in photoItems where !existingPhotoDataSet.contains(item.imageData) {
                let photo = PlantPhoto(imageData: item.imageData, assetIdentifier: item.assetIdentifier, plant: plant)
                modelContext.insert(photo)
                plant.photos.append(photo)
            }
            
            isPresented = false
        }
    }
}

#Preview("Plant Detail") {
    let container = try! ModelContainer(
        for: Plant.self, Bed.self, BedRow.self, PlantPhoto.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let bed = Bed(name: "Bed 1", positionCount: 10)
    let rowA = BedRow(identifier: "A", bed: bed)
    bed.rows = [rowA]
    container.mainContext.insert(bed)
    
    let plant = Plant(
        name: "Dahlia 'Winkie Chevron'",
        primaryColor: "#FF69B4",
        rowIdentifier: "A",
        position: 1,
        bed: bed
    )
    container.mainContext.insert(plant)
    
    return NavigationStack {
        PlantDetailView(plant: plant)
    }
    .modelContainer(container)
}
