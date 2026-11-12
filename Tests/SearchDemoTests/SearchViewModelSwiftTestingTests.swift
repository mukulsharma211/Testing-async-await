#if canImport(Testing)
import Testing
import Clocks
@testable import SearchDemo

/// Same doubles, Swift Testing syntax (Xcode 16+).
/// The whole suite is @MainActor — no inherited setUp to fight.
@Suite("SearchViewModel (Swift Testing)")
@MainActor
struct SearchViewModelSwiftTests {

    @Test func showsLoadingThenResults() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("cricket")
        await service.waitForCall()
        #expect(sut.state == .loading)

        await service.complete(with: [.stub])
        await sut.searchTask?.value
        #expect(sut.state == .loaded([.stub]))
    }

    @Test func staleResponseArrivingLast_isIgnored() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("crick")
        await service.waitForCall()
        let firstTask = sut.searchTask

        sut.queryChanged("cricket")
        await service.complete(with: [.old])
        await firstTask?.value
        #expect(sut.state != .loaded([.old]))

        await service.waitForCall()
        await service.complete(with: [.new])
        await sut.searchTask?.value
        #expect(sut.state == .loaded([.new]))
    }

    @Test func failure_mapsToFailedState() async {
        let service = ControlledSearchService()
        let sut = makeSUT(service: service)

        sut.queryChanged("cricket")
        await service.waitForCall()
        await service.fail(with: TestError())
        await sut.searchTask?.value

        #expect(sut.state == .failed("Network down"))
    }

    @Test(arguments: [299, 300])
    func debounceBoundary(ms: Int) async {
        let clock = TestClock()
        let service = ControlledSearchService()
        let sut = makeSUT(service: service, clock: clock)

        sut.queryChanged("cricket")
        await clock.advance(by: .milliseconds(ms))

        if ms >= 300 {
            await service.waitForCall()
            #expect(await service.queries == ["cricket"])
            await service.complete(with: [])
            await sut.searchTask?.value
        } else {
            #expect(await service.queries.isEmpty)
            sut.queryChanged("")                  // cancel the pending sleeper
            await sut.searchTask?.value
        }
    }
}
#endif
