import UIKit
import SwiftUI
import Foundation

extension UIViewController {
    
    /**
     Creates a dialog with a message and a single OK button.
     
     - Parameters:
        - title: The title of the dialog.
        - message: The message to display in the dialog.
        - buttonTitle: The title for the OK button (defaults to "OK").
        - completion: An optional completion handler to be called when the user taps the OK button.
     */
    func showAlert(title: String, message: String, buttonTitle: String = "OK", completion: (() -> Void)? = nil) {
        AppLogger.log(tag: "LOG-APP: UIViewController+Extensions", message: "showAlert() Showing alert with title: \(title), message: \(message)")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: buttonTitle, style: .default) { _ in
            completion?()
        }
        
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    /**
     Creates a dialog with a message and two buttons for confirmation.
     
     - Parameters:
        - title: The title of the dialog.
        - message: The message to display in the dialog.
        - confirmTitle: The title for the confirm button (defaults to "Yes").
        - cancelTitle: The title for the cancel button (defaults to "No").
        - confirmHandler: The action to perform when the user confirms.
        - cancelHandler: An optional action to perform when the user cancels.
     */
    func showConfirmationAlert(
        title: String,
        message: String,
        confirmTitle: String = "Yes",
        cancelTitle: String = "No",
        confirmHandler: @escaping () -> Void,
        cancelHandler: (() -> Void)? = nil
    ) {
        AppLogger.log(tag: "LOG-APP: UIViewController+Extensions", message: "showConfirmationAlert() Showing confirmation alert with title: \(title), message: \(message)")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: confirmTitle, style: .default) { _ in
            confirmHandler()
        }
        
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            cancelHandler?()
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        
        present(alert, animated: true, completion: nil)
    }

    func convertToPST(from date: Date) -> String {
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' hh:mm:ss a"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    // MARK: - SwiftUI Hosting
    
    public func presentSubscriptionPopup(
        tier: SubscriptionTier,
        title: String,
        infoText: String,
        watchAdButtonText: String = "Watch Advertisement - FREE",
        showWatchAdButton: Bool = true,
        onWatchAd: @escaping () -> Void,
        subscribeButtonText: String,
        onSubscribe: @escaping () -> Void
    ) {
        // Use a binding to allow the popup to dismiss itself
        let isPresented = Binding<Bool>(
            get: { true },
            set: { _, _ in
                self.dismiss(animated: true, completion: nil)
            }
        )
        
        let popupView = SubscriptionPopupView(
            tier: tier,
            title: title,
            infoText: infoText,
            watchAdButtonText: watchAdButtonText,
            showWatchAdButton: showWatchAdButton,
            onWatchAd: onWatchAd,
            subscribeButtonText: subscribeButtonText,
            onSubscribe: onSubscribe,
            isPresented: isPresented
        )
        
        let hostingController = UIHostingController(rootView: popupView)
        hostingController.modalPresentationStyle = .overCurrentContext
        hostingController.modalTransitionStyle = .crossDissolve
        hostingController.view.backgroundColor = .clear
        
        self.present(hostingController, animated: true, completion: nil)
    }
}