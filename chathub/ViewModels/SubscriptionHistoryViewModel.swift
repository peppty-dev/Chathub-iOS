import Foundation
import Combine
import FirebaseFirestore

/**
 * Enhanced ViewModel with pagination support (Android parity)
 * Matches Android's SubscriptionHistoryViewModel functionality
 */
class SubscriptionHistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var historyItems: [SubscriptionHistoryItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var isLastPage: Bool = false
    
    // MARK: - Private Properties
    
    private let repository = SubscriptionRepository.shared
    private static let pageSize = 15 // Match Android PAGE_SIZE
    private var lastDocument: DocumentSnapshot?
    private var currentHistoryList: [SubscriptionHistoryItem] = []
    
    // MARK: - Public Methods
    
    func fetchHistory() {
        AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "fetchHistory() starting initial fetch")
        
        // Reset pagination state
        lastDocument = nil
        currentHistoryList.removeAll()
        isLastPage = false
        
        loadNextPage()
    }
    
    func loadNextPage() {
        // Prevent multiple simultaneous loads
        if isLoading || isLoadingMore || isLastPage {
            AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "loadNextPage() skipping - already loading or last page")
            return
        }
        
        if lastDocument == nil {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        errorMessage = nil
        
        AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "loadNextPage() loading page with size \(Self.pageSize)")
        
        repository.fetchSubscriptionHistoryPage(
            pageSize: Self.pageSize,
            startAfter: lastDocument
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let pageResult):
                    AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "loadNextPage() successfully loaded \(pageResult.items.count) items")
                    
                    // Add new items to current list
                    self.currentHistoryList.append(contentsOf: pageResult.items)
                    self.historyItems = Array(self.currentHistoryList) // Create new array for SwiftUI update
                    
                    // Update pagination state
                    self.lastDocument = pageResult.lastDocument
                    self.isLastPage = pageResult.isLastPage
                    
                    self.errorMessage = nil
                    
                case .failure(let error):
                    AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "loadNextPage() error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    
                    // If this was the first page, clear the list
                    if self.lastDocument == nil {
                        self.historyItems = []
                        self.currentHistoryList.removeAll()
                    }
                }
            }
        }
    }
    
    func refreshHistory() {
        AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "refreshHistory() refreshing history")
        fetchHistory()
    }
    
    func retryFetch() {
        AppLogger.log(tag: "LOG-APP: SubscriptionHistoryViewModel", message: "retryFetch() retrying subscription history fetch")
        fetchHistory()
    }
    
    // MARK: - Helper Methods
    
    func shouldLoadMore(currentItem: SubscriptionHistoryItem) -> Bool {
        guard !isLoading && !isLoadingMore && !isLastPage else { return false }
        
        // Load more when we're near the end
        if let lastItem = historyItems.last, lastItem.id == currentItem.id {
            return true
        }
        
        // Alternative: Load when we're 5 items from the end
        if let currentIndex = historyItems.firstIndex(where: { $0.id == currentItem.id }),
           currentIndex >= historyItems.count - 5 {
            return true
        }
        
        return false
    }
} 