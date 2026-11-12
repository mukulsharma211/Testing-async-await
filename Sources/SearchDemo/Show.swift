import Foundation

public struct Show: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}
