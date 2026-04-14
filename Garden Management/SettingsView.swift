//
//  SettingsView.swift
//  Garden Management
//
//  Settings view with backup and restore functionality
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showImportConfirmation = false
    @State private var importMode: BackupManager.ImportMode = .merge
    @State private var pendingImportURL: URL?
    
    @State private var exportData: Data?
    @State private var alertMessage: AlertMessage?
    @State private var showDeleteAllConfirmation = false
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup & Restore")
                } footer: {
                    Text("Export your garden data to a JSON file for backup. Import will let you choose to replace all data or merge with existing data.")
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Permanently delete all beds, plants, and photos from this device. This action cannot be undone.")
                }
                
                Section {
                    Text("Version 1.0")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .disabled(isImporting)
            .overlay {
                if isImporting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Importing photos from iCloud...")
                            .font(.headline)
                    }
                    .padding(32)
                    #if os(iOS)
                    .background(Color(UIColor.systemBackground))
                    #elseif os(macOS)
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: JSONDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: BackupManager.generateFilename()
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .alert("Import Mode", isPresented: $showImportConfirmation) {
            Button("Replace All Data", role: .destructive) {
                if let url = pendingImportURL {
                    importBackup(from: url, mode: .replace)
                }
            }
            Button("Merge with Existing") {
                if let url = pendingImportURL {
                    importBackup(from: url, mode: .merge)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("Choose how to import:\n\n• Replace: Delete all existing data first\n• Merge: Keep existing data and add imported data")
        }
        .alert("Delete All Data", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("Are you sure you want to delete ALL beds, plants, and photos?\n\nThis will permanently remove all your garden data from this device. This action cannot be undone.\n\nConsider exporting a backup first.")
        }
        .alert(
            alertMessage?.title ?? "Alert",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = alertMessage?.message {
                Text(message)
            }
        }
    }
    
    // MARK: - Export
    
    private func exportBackup() {
        do {
            let data = try BackupManager.exportData(from: modelContext)
            exportData = data
            showExporter = true
        } catch {
            alertMessage = AlertMessage(
                title: "Export Failed",
                message: "Could not export garden data: \(error.localizedDescription)"
            )
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = AlertMessage(
                title: "Export Successful",
                message: "Backup saved to \(url.lastPathComponent)"
            )
        case .failure(let error):
            alertMessage = AlertMessage(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }
    
    // MARK: - Import
    
    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Validate the file first
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = AlertMessage(
                    title: "Access Denied",
                    message: "Could not access the selected file"
                )
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                guard BackupManager.validateBackupData(data) else {
                    alertMessage = AlertMessage(
                        title: "Invalid Backup",
                        message: "The selected file is not a valid garden backup"
                    )
                    return
                }
                
                // Show confirmation dialog
                pendingImportURL = url
                showImportConfirmation = true
                
            } catch {
                alertMessage = AlertMessage(
                    title: "Import Failed",
                    message: "Could not read backup file: \(error.localizedDescription)"
                )
            }
            
        case .failure(let error):
            alertMessage = AlertMessage(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }
    
    private func importBackup(from url: URL, mode: BackupManager.ImportMode) {
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = AlertMessage(
                title: "Access Denied",
                message: "Could not access the selected file"
            )
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        isImporting = true
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                try await BackupManager.importData(data, into: modelContext, mode: mode)
                
                let modeText = mode == .replace ? "replaced" : "merged"
                await MainActor.run {
                    isImporting = false
                    alertMessage = AlertMessage(
                        title: "Import Successful",
                        message: "Garden data has been \(modeText) successfully"
                    )
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    alertMessage = AlertMessage(
                        title: "Import Failed",
                        message: error.localizedDescription
                    )
                }
            }
            
            await MainActor.run {
                pendingImportURL = nil
            }
        }
    }
    
    // MARK: - Delete All Data
    
    private func deleteAllData() {
        do {
            // Fetch and delete all data
            let photoDescriptor = FetchDescriptor<PlantPhoto>()
            let photos = try modelContext.fetch(photoDescriptor)
            for photo in photos {
                modelContext.delete(photo)
            }
            
            let plantDescriptor = FetchDescriptor<Plant>()
            let plants = try modelContext.fetch(plantDescriptor)
            for plant in plants {
                modelContext.delete(plant)
            }
            
            let rowDescriptor = FetchDescriptor<BedRow>()
            let rows = try modelContext.fetch(rowDescriptor)
            for row in rows {
                modelContext.delete(row)
            }
            
            let bedDescriptor = FetchDescriptor<Bed>()
            let beds = try modelContext.fetch(bedDescriptor)
            for bed in beds {
                modelContext.delete(bed)
            }
            
            try modelContext.save()
            
            alertMessage = AlertMessage(
                title: "Data Deleted",
                message: "All garden data has been permanently deleted."
            )
        } catch {
            alertMessage = AlertMessage(
                title: "Delete Failed",
                message: "Could not delete data: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Supporting Types

struct AlertMessage {
    let title: String
    let message: String
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Bed.self, BedRow.self, Plant.self, PlantPhoto.self], inMemory: true)
}
