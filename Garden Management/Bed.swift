//
//  Bed.swift
//  Garden Management
//
//  Created by Brendon Kelly on 6/4/2026.
//

import Foundation
import SwiftData

@Model
final class Bed {
    var name: String
    var positionCount: Int
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \BedRow.bed)
    var rows: [BedRow] = []
    
    @Relationship(deleteRule: .cascade)
    var plants: [Plant] = []
    
    init(name: String, positionCount: Int = 10, createdAt: Date = Date()) {
        self.name = name
        self.positionCount = positionCount
        self.createdAt = createdAt
    }
    
    var displayName: String {
        if name.lowercased().hasPrefix("bed") {
            return name
        } else {
            return "Bed \(name)"
        }
    }
}

@Model
final class BedRow {
    var identifier: String // e.g., "A", "B", "C"
    var bed: Bed?
    
    init(identifier: String, bed: Bed? = nil) {
        self.identifier = identifier
        self.bed = bed
    }
}
