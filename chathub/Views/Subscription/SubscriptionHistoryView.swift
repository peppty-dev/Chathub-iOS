import SwiftUI
import Combine

// MARK: - Main View
struct SubscriptionHistoryView: View {
    @StateObject private var viewModel = SubscriptionHistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.historyItems.isEmpty {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                Spacer()
            } else if viewModel.historyItems.isEmpty && !viewModel.isLoading {
                SubscriptionEmptyStateView(viewModel: viewModel)
            } else {
                List {
                    ForEach(viewModel.historyItems) { item in
                        SubscriptionHistoryRow(item: item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .listRowSeparator(.hidden)
                            .onAppear {
                                // Trigger pagination when near end (Android parity)
                                if viewModel.shouldLoadMore(currentItem: item) {
                                    viewModel.loadNextPage()
                                }
                            }
                    }
                    
                    // Loading more indicator (Android parity)
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("Loading more...")
                                .font(.system(size: 14))
                                .foregroundColor(Color("shade5"))
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    viewModel.refreshHistory()
                }
            }
        }
        .background(Color("Background Color").edgesIgnoringSafeArea(.all))
        .navigationTitle("Subscription History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchHistory()
        }
    }
}

// MARK: - Subviews
private struct SubscriptionEmptyStateView: View {
    @ObservedObject var viewModel: SubscriptionHistoryViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(viewModel.errorMessage ?? "No subscription history found.")
                .font(.headline)
                .foregroundColor(Color("dark"))
            
            if viewModel.errorMessage != nil {
                Button("Retry") {
                    viewModel.fetchHistory()
                }
                .foregroundColor(Color("ColorAccent"))
            }
            Spacer()
            Spacer() // Pushes the content to the vertical center
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
struct SubscriptionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SubscriptionHistoryView()
        }
    }
}