//
//  ThumbnailCache.swift
//  Garden Management
//
//  Performance optimization for grid view with many plants
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private var cache: [String: Data] = [:]
    private let maxCacheSize = 100 // Keep last 100 thumbnails
    
    private init() {}
    
    func getThumbnail(for key: String, imageData: Data, size: CGFloat) async -> Data? {
        // Check if already cached
        if let cachedData = cache[key] {
            return cachedData
        }
        
        // Generate thumbnail
        guard let thumbnailData = await generateThumbnail(from: imageData, size: size) else {
            return nil
        }
        
        // Cache it
        cache[key] = thumbnailData
        
        // Trim cache if needed
        if cache.count > maxCacheSize {
            let oldestKeys = Array(cache.keys.prefix(cache.count - maxCacheSize))
            for key in oldestKeys {
                cache.removeValue(forKey: key)
            }
        }
        
        return thumbnailData
    }
    
    private func generateThumbnail(from imageData: Data, size: CGFloat) async -> Data? {
        #if os(iOS)
        guard let image = UIImage(data: imageData) else { return nil }
        
        // Calculate aspect-fit size to preserve aspect ratio
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        let targetSize: CGSize
        if aspectRatio > 1 {
            // Landscape: width is limiting factor
            targetSize = CGSize(width: size, height: size / aspectRatio)
        } else {
            // Portrait or square: height is limiting factor
            targetSize = CGSize(width: size * aspectRatio, height: size)
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        let thumbnail = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        return thumbnail.jpegData(compressionQuality: 0.7)
        
        #elseif os(macOS)
        guard let image = NSImage(data: imageData) else { return nil }
        
        // Calculate aspect-fit size to preserve aspect ratio
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        let targetSize: CGSize
        if aspectRatio > 1 {
            // Landscape: width is limiting factor
            targetSize = CGSize(width: size, height: size / aspectRatio)
        } else {
            // Portrait or square: height is limiting factor
            targetSize = CGSize(width: size * aspectRatio, height: size)
        }
        
        let thumbnail = NSImage(size: targetSize)
        
        thumbnail.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: targetSize),
                   from: .zero,
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData
        #endif
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

/// Async thumbnail image view that loads images off the main thread
struct ThumbnailImageView: View {
    let imageData: Data
    let size: CGFloat
    let cacheKey: String
    
    @State private var thumbnailData: Data?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let thumbnailData = thumbnailData {
                Image(data: thumbnailData)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        ProgressView()
                    }
            } else {
                // Failed to load
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let data = await ThumbnailCache.shared.getThumbnail(
            for: cacheKey,
            imageData: imageData,
            size: size * 2 // 2x for retina displays
        )
        
        await MainActor.run {
            thumbnailData = data
            isLoading = false
        }
    }
}
