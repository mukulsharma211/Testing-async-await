# AsyncVMTestingDemo

Companion sample for the blog **"Testing async/await ViewModels in Swift Without Flaky Tests"**.
A debounced OTT-style search screen (loading / results / empty / error / cancellation) with
fully deterministic tests: no `Task.sleep`, no `Task.yield()` loops, no `wait(for:)`.

## Requirements
- Xcode 15+ (Xcode 16+ for the Swift Testing suite — it's wrapped in `#if canImport(Testing)`)
- iOS 16 / tvOS 16 / macOS 13 (for the `Clock` protocol)
- Test-only dependency: [pointfreeco/swift-clocks](https://github.com/pointfreeco/swift-clocks) (`TestClock`, `ImmediateClock`)

## Run it
```bash
open Package.swift          # Xcode opens it as a package
# ⌘U to run tests, or:
swift test                  # on macOS
```
To see the UI: open `SearchView.swift` and use the **#Preview** canvas, or add this package to any
iOS/tvOS app and show `SearchView()`.

## Layout
```
Sources/SearchDemo/
  Show.swift               model
  SearchService.swift      SearchServicing protocol + production actor (fake latency + cache)
  SearchViewModel.swift    the @MainActor ViewModel from the blog
  SearchView.swift         SwiftUI demo screen (.searchable works on tvOS too)
Tests/SearchDemoTests/
  TestDoubles.swift        fixtures, StubSearchService, ControlledSearchService (actor), makeSUT()
  SearchViewModelTests.swift              XCTest suite (8 tests)
  SearchViewModelSwiftTestingTests.swift  Swift Testing suite (incl. parameterized debounce boundary)
```

## What each test proves

| Test | Technique | Proves |
|---|---|---|
| `test_search_withResults_setsLoaded` | Stub + `await searchTask?.value` | happy path mapping |
| `test_search_withNoResults_setsEmpty` | Stub | empty state |
| `test_search_whenServiceThrows_setsFailed` | Stub throwing | error mapping |
| `test_whitespaceQuery_staysIdle_...` | Controlled service | guard path never hits network |
| `test_search_showsLoadingThenResults` | `waitForCall()` pauses request | `.loading` is observable mid-flight |
| `test_newQuery_ignoresStaleResults` | complete old request *after* new one | stale response can't overwrite fresh |
| `test_clearingQuery_whileLoading_...` | cancel mid-flight | clear button wins over in-flight result |
| `test_typingQuickly_searchesOnlyLastQuery` | `TestClock.advance` | debounce: nothing before 300 ms, only last keystroke sent |

## Live demo script (for a talk / video)

1. **Run all tests** → green in milliseconds. Show the test timing in the Report navigator.
2. **Break cancellation:** delete `try Task.checkCancellation()` in `SearchViewModel.performSearch`.
   Run → `test_newQuery_ignoresStaleResults` fails. The test protects real behaviour.
   (In the app, the production `SearchService` returns cached results without suspending, which is
   exactly the case that ignores cancellation.)
3. **Break debounce:** change the default `debounce` to `.milliseconds(100)` in `makeSUT` → the
   debounce test fails at the 299 ms assertion.
4. **Break the clock seam:** replace `clock.sleep(for:)` with `Task.sleep(for:)` → debounce tests
   hang/fail because `TestClock` no longer controls time. That's why time is a dependency.
5. **Show the flaky version** (below) next to the deterministic one and run it with
   *Run Repeatedly… → 1000 iterations*. The flaky one fails eventually; the deterministic one never does.

### The flaky "before" version (don't commit this)
```swift
@MainActor
func test_FLAKY_search_showsResults() async throws {
    let sut = SearchViewModel(service: SearchService(latency: .milliseconds(50)))
    sut.queryChanged("cricket")
    try await Task.sleep(for: .milliseconds(400))   // "just to let things settle"
    guard case .loaded = sut.state else {           // fails on a slow CI runner
        return XCTFail("still \(sut.state)")
    }
}
```
Problems: real time (300 ms debounce + 50 ms latency), real service, no handle on the task,
and it runs ~400 ms instead of ~1 ms.

## Ideas to extend the sample
- **Retry with backoff:** inject the same clock, assert retries at 1s/2s/4s with `TestClock.advance`.
- **Pagination:** `loadNextPage()` as `async` so tests just `await` it — no task handle needed.
- **AsyncStream source:** feed queries via `AsyncStream` and test with a controlled continuation.
- **tvOS Focus:** keep focus logic out of the VM; test only state, verify focus in UI tests.
- **`@Observable` variant (iOS 17+):** same tests work; swap `ObservableObject` for `@Observable`.
# Testing-async-await
