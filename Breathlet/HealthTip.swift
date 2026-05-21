import Foundation
import SwiftUI

struct HealthTip: Identifiable {
    let id: UUID
    let name: String
    let steps: [String]
    let symbolName: String

    init(
        id: UUID = UUID(),
        name: String,
        steps: [String],
        symbolName: String
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.symbolName = symbolName
    }
}