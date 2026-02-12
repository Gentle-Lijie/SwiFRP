import Foundation

enum DeleteMethod: String, Codable, CaseIterable {
    case none
    case absolute
    case relative
}

struct AutoDelete: Codable, Equatable {
    var deleteMethod: DeleteMethod = .none
    var deleteAfterDays: Int = 0
    var deleteAfterDate: Date = Date()
}
