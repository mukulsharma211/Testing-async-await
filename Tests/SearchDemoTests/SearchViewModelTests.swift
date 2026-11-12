import XCTest
import Clocks
@testable import SearchDemo

final class SearchViewModelTests: XCTestCase {

    // MARK: Stub-based (simple state mapping)

    @MainActor
    func test_search_withResults_setsLoaded() async {
        let sut = makeSUT(service: StubSearchService { _ in [.stub] })

        sut.queryChanged("cricket")
        await sut.searchTask?.value

        XCTAssertEqual(sut.state, .loaded([.stub]))
    }

    @MainActor
    func test_search_withNoResults_setsEmpty() async {
        let sut = makeSUT(service: StubSearchService { _ in [] })

        sut.queryChanged("zzz")
        await sut.searchTask?.value

        XCTAssertEqual(sut.state, .empty)
    }

    @MainActor
    func test_search_whenServiceThrows_setsFailed() async {
        let sut = makeSUT(service: StubSearchService { _ in throw TestError() })

        sut.queryChanged("cricket")
        await sut.searchTask?.value

        XCTAssertEqual(sut.state, .failed("Network down"))
    }

    @MainActor
    func test_whitespaceQuery_staysIdle_andNeverCallsService() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("   ")

        XCTAssertNil(sut.searchTask)
        XCTAssertEqual(sut.state, .idle)
        let queries = await service.queries
        XCTAssertTrue(queries.isEmpty)
    }

    // MARK: Assert the in-flight loading state

    @MainActor
    func test_search_showsLoadingThenResults() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("cricket")
        await service.waitForCall()
        XCTAssertEqual(sut.state, .loading)       // request is paused mid-flight

        await service.complete(with: [.stub])
        await sut.searchTask?.value
        XCTAssertEqual(sut.state, .loaded([.stub]))
    }

    // MARK: Cancellation: stale results must not win

    @MainActor
    func test_newQuery_ignoresStaleResults() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("crick")
        await service.waitForCall()
        let firstTask = sut.searchTask

        sut.queryChanged("cricket")
        await service.complete(with: [.old])      // old one finishes late
        await firstTask?.value
        XCTAssertNotEqual(sut.state, .loaded([.old]))

        await service.waitForCall()
        await service.complete(with: [.new])
        await sut.searchTask?.value
        XCTAssertEqual(sut.state, .loaded([.new]))
    }

    @MainActor
    func test_clearingQuery_whileLoading_returnsToIdle_andDropsResult() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("cricket")
        await service.waitForCall()
        let task = sut.searchTask

        sut.queryChanged("")                      // user hits clear
        await service.complete(with: [.stub])
        await task?.value

        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: Debounce with a controllable clock

    @MainActor
    func test_typingQuickly_searchesOnlyLastQuery() async {
        let clock = TestClock()
        let service = ControlledSearchService()
        let sut = makeSUT(service: service, clock: clock)

        ["c", "cr", "cri"].forEach(sut.queryChanged)

        await clock.advance(by: .milliseconds(299))
        let early = await service.queries
        XCTAssertTrue(early.isEmpty)              // nothing fires before 300 ms

        await clock.advance(by: .milliseconds(1))
        await service.waitForCall()
        let queries = await service.queries
        XCTAssertEqual(queries, ["cri"])          // earlier keystrokes were cancelled

        await service.complete(with: [])
        await sut.searchTask?.value
    }
}
