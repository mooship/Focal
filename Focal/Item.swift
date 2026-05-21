//
//  Item.swift
//  Focal
//
//  Created by Timothy Brits on 2026/05/21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
