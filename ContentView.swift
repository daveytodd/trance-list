import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FeedViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.videos) { video in
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                    Text("\(video.published, formatter: dateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Link("Watch on YouTube", destination: video.link)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("ASOT Episodes")
            .refreshable {
                await viewModel.load()
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
}

// MARK: - ViewModel

final class FeedViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    private let service = RSSService()

    @MainActor
    func load() {
        service.fetchVideos { [weak self] result in
            switch result {
            case .success(let items):
                self?.videos = items.sorted { $0.published > $1.published }
            case .failure(let error):
                print("Failed to load feed: \(error.localizedDescription)")
                self?.videos = []
            }
        }
    }
}
