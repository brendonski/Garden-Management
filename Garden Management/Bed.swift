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
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \BedRow.bed)
    var rows: [BedRow] = []
    
    @Relationship(deleteRule: .cascade)
    var plants: [Plant] = []
    
    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class BedRow {
    var identifier: String // e.g., "A", "B", "C"
    var positionCount: Int
    var bed: Bed?
    
    init(identifier: String, positionCount: Int, bed: Bed? = nil) {
        self.identifier = identifier
        self.positionCount = positionCount
        self.bed = bed
    }
}
