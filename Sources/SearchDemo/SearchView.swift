import SwiftUI

/// Demo screen. Works on iOS and tvOS (.searchable gives the tvOS keyboard grid).
public struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @State private var query = ""

    public init(viewModel: @autoclosure @escaping () -> SearchViewModel =
                    SearchViewModel(service: SearchService())) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: $query, prompt: "Shows, sports…")
                .onChange(of: query) { viewModel.queryChanged($0) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Text("Start typing to search").foregroundStyle(.secondary)
        case .loading:
            ProgressView()
        case .empty:
            Text("No results")
        case .loaded(let shows):
            List(shows) { Text($0.title) }
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        }
    }
}

#Preview {
    SearchView()
}
