import Foundation

/// The seam the tests use. Because the requirement is `async`,
/// an actor, struct or class can all conform.
public protocol SearchServicing: Sendable {
    func search(_ query: String) async throws -> [Show]
}

/// "Production" service for the demo app.
/// Simulates network latency + a cache so the demo runs without a backend.
/// Swap the body for URLSession in a real app.
public actor SearchService: SearchServicing {
    private var cache: [String: [Show]] = [:]
    private let latency: Duration
    private let catalog: [Show] = [
        "Cricket Live", "Cricket Highlights", "Crime Files", "Football Tonight",
        "Formula 1 Replay", "Tennis Masters", "Kabaddi League", "Badminton Open"
    ].enumerated().map { Show(id: $0.offset, title: $0.element) }

    public init(latency: Duration = .milliseconds(800)) {
        self.latency = latency
    }

    public func search(_ query: String) async throws -> [Show] {
        if let cached = cache[query] { return cached }      // returns even if caller was cancelled!
        try await Task.sleep(for: latency)                  // fake network
        let results = catalog.filter { $0.title.localizedCaseInsensitiveContains(query) }
        cache[query] = results
        return results
    }
}
