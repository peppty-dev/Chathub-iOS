import UIKit
import SwiftUI

extension UIViewController {

    var isSubscribed: Bool {
        return SubscriptionSessionManager.shared.isSubscribed
    }

    func showSubscriptionNagScreen() {
        let subscriptionVC = UIHostingController(rootView: SubscriptionView())
        self.present(subscriptionVC, animated: true, completion: nil)
    }
} 