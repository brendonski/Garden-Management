//
//  PhotoLibraryHelper.swift
//  Garden Management
//
//  Helper for working with Photos library and asset identifiers
//

import Foundation
import SwiftUI
import Photos
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PhotoAssetInfo {
    let imageData: Data
    let assetIdentifier: String?
}

class PhotoLibraryHelper {
    
    /// Get asset identifier from PhotosPickerItem
    /// If the item is from the photo library, this retrieves the existing asset identifier
    /// Returns nil if the asset cannot be found
    @MainActor
    static func getAssetIdentifier(from item: PhotosPickerItem) async -> String? {
        // PhotosPickerItem.itemIdentifier is not a PHAsset localIdentifier
        // We need to load the asset and match it
        guard let imageData = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        
        // Try to find the existing asset in the library
        return await findExistingAsset(for: imageData)
    }
    
    /// Find an existing asset in the library that matches the given image data
    /// Returns the asset identifier if found, nil otherwise
    @MainActor
    static func findExistingAsset(for imageData: Data) async -> String? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return nil
        }
        
        #if os(iOS)
        guard let sourceImage = UIImage(data: imageData) else { return nil }
        let imageSize = sourceImage.size
        let imageScale = sourceImage.scale
        #elseif os(macOS)
        guard let sourceImage = NSImage(data: imageData) else { return nil }
        let imageSize = sourceImage.size
        let imageScale: CGFloat = 1.0 // NSImage doesn't have scale property
        #endif
        
        // Calculate a hash of the source image data for comparison
        let sourceDataHash = imageData.hashValue
        
        // Fetch recent photos to search for matches
        // Photos from PhotosPicker should be recent
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 200 // Search last 200 photos for performance
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        // Expected pixel dimensions
        let expectedWidth = Int(imageSize.width * imageScale)
        let expectedHeight = Int(imageSize.height * imageScale)
        
        // Search for a matching asset
        var matchingIdentifier: String?
        
        await withCheckedContinuation { continuation in
            allPhotos.enumerateObjects { asset, _, stop in
                // First filter: Compare by pixel dimensions (fast check)
                let widthMatches = abs(asset.pixelWidth - expectedWidth) <= 1 // Allow 1px tolerance
                let heightMatches = abs(asset.pixelHeight - expectedHeight) <= 1
                
                if widthMatches && heightMatches {
                    // Second filter: Compare actual image data
                    let options = PHImageRequestOptions()
                    options.isSynchronous = true
                    options.isNetworkAccessAllowed = false // Only check local photos for speed
                    options.deliveryMode = .highQualityFormat
                    
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                        if let data = data, data.hashValue == sourceDataHash {
                            // Exact match found
                            matchingIdentifier = asset.localIdentifier
                            stop.pointee = true
                        }
                    }
                }
                
                if matchingIdentifier != nil {
                    stop.pointee = true
                }
            }
            continuation.resume()
        }
        
        return matchingIdentifier
    }
    
    /// Get or create an asset identifier for an image
    /// First checks if the image already exists in the library, otherwise saves it
    @MainActor
    static func getOrCreateAssetIdentifier(for imageData: Data) async -> String? {
        // First, try to find an existing matching asset
        if let existingIdentifier = await findExistingAsset(for: imageData) {
            print("Found existing photo in library: \(existingIdentifier)")
            return existingIdentifier
        }
        
        // No match found, save to library
        #if os(iOS)
        guard let image = UIImage(data: imageData) else { return nil }
        #elseif os(macOS)
        guard let image = NSImage(data: imageData) else { return nil }
        #endif
        
        do {
            let identifier = try await saveAndGetIdentifier(image: image)
            print("Saved new photo to library: \(identifier ?? "none")")
            return identifier
        } catch {
            print("Failed to save photo to library: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save an image to the photo library and return its asset identifier
    @MainActor
    static func saveAndGetIdentifier(image: NativeImage) async throws -> String? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw PhotoError.accessDenied
        }
        
        var assetIdentifier: String?
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetIdentifier = request.placeholderForCreatedAsset?.localIdentifier
        }
        
        return assetIdentifier
    }
    
    /// Load image data from a photo asset using its identifier
    @MainActor
    static func loadImage(withIdentifier identifier: String) async throws -> Data {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoError.accessDenied
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw PhotoError.assetNotFound
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true // Allow download from iCloud
        options.deliveryMode = .highQualityFormat
        
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: PhotoError.loadFailed)
                    return
                }
                
                continuation.resume(returning: data)
            }
        }
    }
    
    /// Check if an asset with the given identifier exists
    @MainActor
    static func assetExists(withIdentifier identifier: String) -> Bool {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.count > 0
    }
    
    /// Get thumbnail for a photo asset
    @MainActor
    static func loadThumbnail(withIdentifier identifier: String, targetSize: CGSize = CGSize(width: 200, height: 200)) async throws -> NativeImage {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoError.accessDenied
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw PhotoError.assetNotFound
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let image = image else {
                    continuation.resume(throwing: PhotoError.loadFailed)
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Platform-specific type aliases

#if os(iOS)
typealias NativeImage = UIImage
#elseif os(macOS)
typealias NativeImage = NSImage
#endif

// MARK: - Errors

enum PhotoError: LocalizedError {
    case accessDenied
    case assetNotFound
    case loadFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access denied. Please enable in Settings."
        case .assetNotFound:
            return "Photo not found in library. It may have been deleted."
        case .loadFailed:
            return "Failed to load photo from library"
        case .saveFailed:
            return "Failed to save photo to library"
        }
    }
}
