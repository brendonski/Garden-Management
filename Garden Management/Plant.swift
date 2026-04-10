//
//  Plant.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import Foundation
import SwiftData

@Model
final class Plant {
    var name: String
    var primaryColor: String?
    var secondaryColor: String?
    var rowIdentifier: String
    var position: Int
    var plantedDate: Date
    var notes: String?
    
    var bed: Bed?
    
    @Relationship(deleteRule: .cascade)
    var photos: [PlantPhoto] = []
    
    init(name: String, primaryColor: String? = nil, secondaryColor: String? = nil, 
         rowIdentifier: String, position: Int, bed: Bed? = nil, 
         plantedDate: Date = Date(), notes: String? = nil) {
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.rowIdentifier = rowIdentifier
        self.position = position
        self.bed = bed
        self.plantedDate = plantedDate
        self.notes = notes
    }
    
    var locationDescription: String {
        if let bedName = bed?.name {
            return "Bed \(bedName), Row \(rowIdentifier), Position \(position)"
        }
        return "Row \(rowIdentifier), Position \(position)"
    }
}

@Model
final class PlantPhoto {
    var imageData: Data
    var capturedDate: Date
    var caption: String?
    
    var plant: Plant?
    
    init(imageData: Data, capturedDate: Date = Date(), caption: String? = nil, plant: Plant? = nil) {
        self.imageData = imageData
        self.capturedDate = capturedDate
        self.caption = caption
        self.plant = plant
    }
}
