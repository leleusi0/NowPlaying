//
//  Item.swift
//  NowPlaying
//
//  Created by Lucas Eleusiniotis on 2026-02-03.
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
