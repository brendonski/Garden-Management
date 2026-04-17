//
//  ColorExtractor.swift
//  Garden Management
//
//  Created by Brendon Kelly on 11/4/2026.
//

import SwiftUI
import Accelerate

struct DominantColor: Identifiable {
    let id = UUID()
    let color: Color
    let hexString: String
    let count: Int
}

class ColorExtractor {
    static func extractDominantColors(from imageData: Data, count: Int = 5) -> [DominantColor] {
        #if os(iOS)
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { return [] }
        #elseif os(macOS)
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        #endif
        
        return extractDominantColors(from: cgImage, count: count)
    }
    
    static func extractDominantColors(from cgImage: CGImage, count: Int = 5) -> [DominantColor] {
        let width = cgImage.width
        let height = cgImage.height
        
        // Resize image to reduce processing time
        let maxDimension = 150
        let scale = min(1.0, Double(maxDimension) / Double(max(width, height)))
        let scaledWidth = Int(Double(width) * scale)
        let scaledHeight = Int(Double(height) * scale)
        
        // Create bitmap context
        var pixelData = [UInt8](repeating: 0, count: scaledWidth * scaledHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        
        // Track color frequency and properties
        var colorStats: [String: (r: Int, g: Int, b: Int, count: Int, brightness: Double, saturation: Double)] = [:]
        
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Int(pixelData[i])
            let g = Int(pixelData[i + 1])
            let b = Int(pixelData[i + 2])
            let a = Int(pixelData[i + 3])
            
            // Skip transparent pixels
            guard a > 128 else { continue }
            
            // Quantize colors to reduce variation (group similar colors)
            let quantizationLevel = 24 // Slightly finer grouping for better color accuracy
            let qr = (r / quantizationLevel) * quantizationLevel
            let qg = (g / quantizationLevel) * quantizationLevel
            let qb = (b / quantizationLevel) * quantizationLevel
            
            let key = "\(qr)-\(qg)-\(qb)"
            
            // Calculate perceived brightness using standard luminance formula
            let brightness = 0.299 * Double(qr) + 0.587 * Double(qg) + 0.114 * Double(qb)
            
            // Calculate saturation (how vibrant the color is)
            let maxVal = max(qr, qg, qb)
            let minVal = min(qr, qg, qb)
            let saturation = maxVal > 0 ? Double(maxVal - minVal) / Double(maxVal) : 0.0
            
            // Accumulate pixel count and properties
            if var existing = colorStats[key] {
                existing.count += 1
                colorStats[key] = existing
            } else {
                colorStats[key] = (qr, qg, qb, 1, brightness, saturation)
            }
        }
        
        // Filter out very dark or very desaturated colors (likely background)
        let filteredColors = colorStats.values.filter { colorData in
            // Exclude very dark colors (brightness < 40)
            guard colorData.brightness > 40 else { return false }
            // Exclude very desaturated/gray colors (saturation < 0.15)
            guard colorData.saturation > 0.15 else { return false }
            return true
        }
        
        // Sort by a score that combines area, brightness, and saturation
        // Prioritize: large area + bright + saturated colors (typical of flowers)
        let sortedColors = filteredColors
            .sorted { colorA, colorB in
                // Calculate score: area coverage × brightness × saturation²
                // Saturation is squared to heavily favor vibrant colors
                let scoreA = Double(colorA.count) * colorA.brightness * pow(colorA.saturation, 2.0)
                let scoreB = Double(colorB.count) * colorB.brightness * pow(colorB.saturation, 2.0)
                return scoreA > scoreB
            }
            .prefix(count)
        
        // Convert to DominantColor objects
        return sortedColors.map { colorData in
            let color = Color(
                red: Double(colorData.r) / 255.0,
                green: Double(colorData.g) / 255.0,
                blue: Double(colorData.b) / 255.0
            )
            let hexString = String(format: "#%02X%02X%02X", colorData.r, colorData.g, colorData.b)
            return DominantColor(color: color, hexString: hexString, count: colorData.count)
        }
    }
}

struct ColorSelectionSheet: View {
    let colors: [DominantColor]
    let photoData: Data?
    let onSelect: (Color, String) -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Show the selected photo if available
                    if let photoData = photoData {
                        Image(data: photoData)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                    
                    // Grid of color squares
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select a color from your photo")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 60), spacing: 12)
                        ], spacing: 12) {
                            ForEach(colors) { dominantColor in
                                Button {
                                    onSelect(dominantColor.color, dominantColor.hexString)
                                    isPresented = false
                                } label: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(dominantColor.color)
                                        .frame(height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Pick Color from Photo")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 600)
#endif
    }
}

struct PhotoSelectionSheet: View {
    let photos: [Data]
    let onSelect: (Data) -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(photos.indices, id: \.self) { index in
                        Button {
                            onSelect(photos[index])
                            isPresented = false
                        } label: {
                            Image(data: photos[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Photo")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
#endif
    }
}
