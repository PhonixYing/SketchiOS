//
//  Item.swift
//  SketchiOS
//
//  Created by LiDonghui on 2026/2/21.
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
