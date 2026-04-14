//
//  BackupManager.swift
//  Garden Management
//
//  Handles export and import of garden data to/from JSON
//

import Foundation
import SwiftData

// MARK: - Codable Transfer Objects

struct BackupData: Codable {
    let version: Int = 1
    let exportDate: Date
    let beds: [BedBackup]
    
    struct BedBackup: Codable {
        let name: String
        let positionCount: Int
        let createdAt: Date
        let rows: [BedRowBackup]
        let plants: [PlantBackup]
    }
    
    struct BedRowBackup: Codable {
        let identifier: String
    }
    
    struct PlantBackup: Codable {
        let name: String
        let primaryColor: String?
        let secondaryColor: String?
        let rowIdentifier: String
        let position: Int
        let enteredDate: Date
        let notes: String?
        let photos: [PlantPhotoBackup]
    }
    
    struct PlantPhotoBackup: Codable {
        let capturedDate: Date
        let caption: String?
        let assetIdentifier: String?  // PHAsset localIdentifier for iCloud reference
    }
}

// MARK: - Backup Manager

@MainActor
class BackupManager {
    
    // MARK: - Export
    
    static func exportData(from modelContext: ModelContext) throws -> Data {
        let descriptor = FetchDescriptor<Bed>(sortBy: [SortDescriptor(\.createdAt)])
        let beds = try modelContext.fetch(descriptor)
        
        let bedBackups = beds.map { bed -> BackupData.BedBackup in
            let rowBackups = bed.rows.map { row in
                BackupData.BedRowBackup(identifier: row.identifier)
            }
            
            let plantBackups = bed.plants.map { plant -> BackupData.PlantBackup in
                let photoBackups = plant.photos.map { photo in
                    BackupData.PlantPhotoBackup(
                        capturedDate: photo.capturedDate,
                        caption: photo.caption,
                        assetIdentifier: photo.assetIdentifier
                    )
                }
                
                return BackupData.PlantBackup(
                    name: plant.name,
                    primaryColor: plant.primaryColor,
                    secondaryColor: plant.secondaryColor,
                    rowIdentifier: plant.rowIdentifier,
                    position: plant.position,
                    enteredDate: plant.enteredDate,
                    notes: plant.notes,
                    photos: photoBackups
                )
            }
            
            return BackupData.BedBackup(
                name: bed.name,
                positionCount: bed.positionCount,
                createdAt: bed.createdAt,
                rows: rowBackups,
                plants: plantBackups
            )
        }
        
        let backup = BackupData(exportDate: Date(), beds: bedBackups)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(backup)
    }
    
    // MARK: - Import
    
    enum ImportMode {
        case replace  // Delete all existing data first
        case merge    // Keep existing data, add imported data
    }
    
    @MainActor
    static func importData(_ data: Data, into modelContext: ModelContext, mode: ImportMode) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup = try decoder.decode(BackupData.self, from: data)
        
        // Validate version
        guard backup.version == 1 else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        
        // Replace mode: delete all existing data
        if mode == .replace {
            try deleteAllData(from: modelContext)
        }
        
        // Import beds
        for bedBackup in backup.beds {
            let bed = Bed(
                name: bedBackup.name,
                positionCount: bedBackup.positionCount,
                createdAt: bedBackup.createdAt
            )
            modelContext.insert(bed)
            
            // Import rows
            for rowBackup in bedBackup.rows {
                let row = BedRow(identifier: rowBackup.identifier, bed: bed)
                modelContext.insert(row)
            }
            
            // Import plants
            for plantBackup in bedBackup.plants {
                let plant = Plant(
                    name: plantBackup.name,
                    primaryColor: plantBackup.primaryColor,
                    secondaryColor: plantBackup.secondaryColor,
                    rowIdentifier: plantBackup.rowIdentifier,
                    position: plantBackup.position,
                    bed: bed,
                    enteredDate: plantBackup.enteredDate,
                    notes: plantBackup.notes
                )
                modelContext.insert(plant)
                
                // Import photos
                for photoBackup in plantBackup.photos {
                    var imageData = Data()
                    
                    // Try to load image from Photos library if asset identifier is available
                    if let assetId = photoBackup.assetIdentifier {
                        do {
                            imageData = try await PhotoLibraryHelper.loadImage(withIdentifier: assetId)
                        } catch {
                            // If photo can't be loaded from library, skip it with a warning
                            print("Warning: Could not load photo with identifier \(assetId): \(error.localizedDescription)")
                            continue
                        }
                    }
                    
                    // Only create photo if we have actual image data
                    guard !imageData.isEmpty else { continue }
                    
                    let photo = PlantPhoto(
                        imageData: imageData,
                        capturedDate: photoBackup.capturedDate,
                        caption: photoBackup.caption,
                        assetIdentifier: photoBackup.assetIdentifier,
                        plant: plant
                    )
                    modelContext.insert(photo)
                }
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Helper Methods
    
    private static func deleteAllData(from modelContext: ModelContext) throws {
        // Fetch and delete individually to properly handle relationships
        
        // Delete PlantPhotos first
        let photoDescriptor = FetchDescriptor<PlantPhoto>()
        let photos = try modelContext.fetch(photoDescriptor)
        for photo in photos {
            modelContext.delete(photo)
        }
        
        // Delete Plants
        let plantDescriptor = FetchDescriptor<Plant>()
        let plants = try modelContext.fetch(plantDescriptor)
        for plant in plants {
            modelContext.delete(plant)
        }
        
        // Delete BedRows
        let rowDescriptor = FetchDescriptor<BedRow>()
        let rows = try modelContext.fetch(rowDescriptor)
        for row in rows {
            modelContext.delete(row)
        }
        
        // Delete Beds
        let bedDescriptor = FetchDescriptor<Bed>()
        let beds = try modelContext.fetch(bedDescriptor)
        for bed in beds {
            modelContext.delete(bed)
        }
        
        try modelContext.save()
    }
    
    static func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        return "GardenBackup_\(dateString).json"
    }
    
    static func validateBackupData(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let backup = try decoder.decode(BackupData.self, from: data)
            return backup.version == 1
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidData
    case exportFailed(Error)
    case importFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Backup version \(version) is not supported"
        case .invalidData:
            return "The backup file is invalid or corrupted"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Import failed: \(error.localizedDescription)"
        }
    }
}
