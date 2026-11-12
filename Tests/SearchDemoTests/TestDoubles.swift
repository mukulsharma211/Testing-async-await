import Foundation
import Clocks
@testable import SearchDemo

// MARK: - Fixtures

extension Show {
    static let stub = Show(id: 1, title: "Cricket Live")
    static let old  = Show(id: 2, title: "Crick (stale)")
    static let new  = Show(id: 3, title: "Cricket (fresh)")
}

struct TestError: LocalizedError, Equatable {
    var errorDescription: String? { "Network down" }
}

// MARK: - Stub: "given this response, state becomes X"

struct StubSearchService: SearchServicing {
    let handler: @Sendable (String) async throws -> [Show]

    func search(_ query: String) async throws -> [Show] {
        try await handler(query)
    }
}

// MARK: - Controlled service: pause requests mid-flight

/// The test decides WHEN each request completes.
/// Actor => no data races inside the mock itself.
actor ControlledSearchService: SearchServicing {
    private(set) var queries: [String] = []
    private var pending: [CheckedContinuation<[Show], Error>] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func search(_ query: String) async throws -> [Show] {
        queries.append(query)
        return try await withCheckedThrowingContinuation {
            pending.append($0)
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    /// Suspends until the ViewModel has actually called `search`. No polling, no yields.
    func waitForCall() async {
        guard pending.isEmpty else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func complete(with shows: [Show]) {
        pending.removeFirst().resume(returning: shows)
    }

    func fail(with error: Error) {
        pending.removeFirst().resume(throwing: error)
    }
}

// MARK: - SUT factory (instead of setUp — sidesteps Swift 6 isolation issues)

@MainActor
func makeSUT(service: SearchServicing,
             clock: any Clock<Duration> = ImmediateClock(),
             debounce: Duration = .milliseconds(300)) -> SearchViewModel {
    SearchViewModel(service: service, clock: clock, debounce: debounce)
}
