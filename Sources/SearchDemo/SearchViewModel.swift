import Foundation
import Combine

@MainActor
public final class SearchViewModel: ObservableObject {
    public enum State: Equatable {
        case idle, loading, empty
        case loaded([Show])
        case failed(String)
    }

    @Published public private(set) var state: State = .idle

    /// Exposed (read-only) purely so tests can `await sut.searchTask?.value`.
    public private(set) var searchTask: Task<Void, Never>?

    private let service: SearchServicing
    private let clock: any Clock<Duration>
    private let debounce: Duration

    public init(service: SearchServicing,
                clock: any Clock<Duration> = ContinuousClock(),
                debounce: Duration = .milliseconds(300)) {
        self.service = service
        self.clock = clock
        self.debounce = debounce
    }

    public func queryChanged(_ text: String) {
        searchTask?.cancel()                                  // newer query wins
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { state = .idle; return }
        searchTask = Task { [weak self] in
            await self?.performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        do {
            try await clock.sleep(for: debounce)
            state = .loading
            let results = try await service.search(query)
            try Task.checkCancellation()                      // drop stale results
            state = results.isEmpty ? .empty : .loaded(results)
        } catch is CancellationError {
            // superseded by a newer query
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
