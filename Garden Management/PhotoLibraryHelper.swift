//
//  PhotoLibraryHelper.swift
//  Garden Management
//
//  Helper for working with Photos library and asset identifiers
//

import Foundation
import Photos

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
