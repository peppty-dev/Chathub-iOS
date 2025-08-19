//
//  CaptureProtection.swift
//  ChatHub
//
//  In-house screenshot and screen recording protection system
//  Created for anonymous chat application
//

import SwiftUI
import Combine
import UIKit

// MARK: - Capture Protection Manager
final class CaptureProtection: ObservableObject {
    @Published var appWideEnabled = false
    @Published var showOverlay = false
    @Published var screenshotCount = 0
    
    private var bag = Set<AnyCancellable>()
    
    func start() {
        AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "start() - Initializing screenshot protection system")
        
        // Detect screenshot attempts
        NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)
            .sink { [weak self] _ in
                self?.handleScreenshotAttempt()
            }
            .store(in: &bag)
        
        // Detect screen recording (iOS 11+)
        if #available(iOS 11.0, *) {
            NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
                .sink { [weak self] _ in
                    self?.handleScreenRecordingChange()
                }
                .store(in: &bag)
        }
    }
    
    private func handleScreenshotAttempt() {
        screenshotCount += 1
        AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "handleScreenshotAttempt() - Screenshot attempt #\(screenshotCount) detected in anonymous chat")
        
        // Post notification for views to handle
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ScreenshotAttemptDetected"),
                object: nil,
                userInfo: ["attemptCount": self.screenshotCount]
            )
        }
    }
    
    private func handleScreenRecordingChange() {
        if #available(iOS 11.0, *) {
            showOverlay = UIScreen.main.isCaptured
            AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "handleScreenRecordingChange() - Screen recording state: \(UIScreen.main.isCaptured)")
        }
    }
}

// MARK: - App-Wide Capture Shield
struct AppWideCaptureShield: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @ObservedObject var protection: CaptureProtection
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if protection.appWideEnabled && (protection.showOverlay || phase != .active) {
                // Branded overlay for background/recording protection
                Color.black.ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                            Text("ChatHub")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Content Protected")
                                .font(.headline)
                            Text("Screenshots and recordings are restricted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding()
                    )
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            if #available(iOS 11.0, *) {
                protection.showOverlay = UIScreen.main.isCaptured
            }
        }
    }
}

// MARK: - Full Screen Screenshot Prevention (Proper Implementation)
struct FullScreenProtectionView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    func makeUIViewController(context: Context) -> ProtectedViewController<Content> {
        return ProtectedViewController(rootView: content)
    }
    
    func updateUIViewController(_ uiViewController: ProtectedViewController<Content>, context: Context) {
        uiViewController.updateContent(content)
    }
}

class ProtectedViewController<Content: View>: UIViewController {
    private var hostingController: UIHostingController<Content>
    private var secureField: UITextField!
    
    init(rootView: Content) {
        self.hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupProtectedView()
    }
    
    private func setupProtectedView() {
        // Create secure text field that fills the entire screen
        secureField = UITextField()
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        secureField.backgroundColor = .clear
        secureField.borderStyle = .none
        secureField.textColor = .clear
        secureField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add hosting controller as child
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add secure field first (bottom layer for visual), then content
        view.addSubview(secureField)
        view.addSubview(hostingController.view)
        
        // Setup constraints - both fill the entire view
        NSLayoutConstraint.activate([
            // Secure field constraints (full screen)
            secureField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content constraints (full screen, on top for user interaction)
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        
        // CRITICAL: Layer arrangement for screenshot protection
        // Move content layer to be a sublayer of the secure field's layer
        if let secureLayer = secureField.layer.sublayers?.first {
            hostingController.view.layer.removeFromSuperlayer()
            secureLayer.addSublayer(hostingController.view.layer)
        }
        
        AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "FullScreenProtectionView - Full screen screenshot prevention applied")
    }
    
    func updateContent(_ content: Content) {
        hostingController.rootView = content
    }
}

struct FullScreenCaptureShield: ViewModifier {
    func body(content: Content) -> some View {
        FullScreenProtectionView(content: content)
            .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Enhanced Secure View (Strong Screenshot Prevention)
struct EnhancedSecureView<Content: View>: UIViewRepresentable {
    let content: Content
    
    func makeUIView(context: Context) -> UIView {
        // Create secure text field as the main container
        let secureField = UITextField()
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        secureField.backgroundColor = .clear
        secureField.borderStyle = .none
        secureField.textAlignment = .center
        secureField.textColor = .clear
        secureField.frame = UIScreen.main.bounds
        
        // Create hosting controller for SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // CRITICAL: Add SwiftUI content as subview to secure text field
        // This ensures the content is protected by the secure text field
        secureField.addSubview(hostingController.view)
        
        // Setup constraints to fill the secure field
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: secureField.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: secureField.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: secureField.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: secureField.bottomAnchor)
        ])
        
        // ENHANCED PROTECTION: Additional layer manipulation
        // This technique helps ensure screenshots are blocked
        if let secureLayer = secureField.layer.sublayers?.first {
            secureLayer.addSublayer(hostingController.view.layer)
            
            // Move the hosting controller's layer to be a sublayer of the secure layer
            hostingController.view.layer.removeFromSuperlayer()
            secureLayer.addSublayer(hostingController.view.layer)
        }
        
        AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "EnhancedSecureView - Strong screenshot prevention applied with secure text field container")
        return secureField
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure protection remains active
        if let textField = uiView as? UITextField {
            textField.isSecureTextEntry = true
            textField.isUserInteractionEnabled = false
        }
    }
}

struct EnhancedSecureViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        EnhancedSecureView(content: content)
    }
}

// MARK: - Smart Screenshot Prevention (Visible during normal use, protected during capture)
struct SmartSecureView<Content: View>: UIViewRepresentable {
    let content: Content
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Create hosting controller for SwiftUI content - this will be visible normally
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Create invisible secure text field overlay for protection
        let secureField = UITextField()
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        secureField.backgroundColor = .clear
        secureField.borderStyle = .none
        secureField.textColor = .clear
        secureField.alpha = 0.01 // Almost invisible but still functional
        secureField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add both views to container
        containerView.addSubview(hostingController.view)
        containerView.addSubview(secureField)
        
        // Setup constraints - both fill the container
        NSLayoutConstraint.activate([
            // Content view constraints (visible content)
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Secure field constraints (protective overlay)
            secureField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: containerView.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // CRITICAL: Layer arrangement for screenshot protection
        // The secure field's layer needs to be on top for screenshot protection
        containerView.layer.addSublayer(secureField.layer)
        
        AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "SmartSecureView - Smart screenshot prevention applied (visible during normal use)")
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure protection remains active
        if let secureField = uiView.subviews.compactMap({ $0 as? UITextField }).first {
            secureField.isSecureTextEntry = true
            secureField.isUserInteractionEnabled = false
        }
    }
}

struct SmartSecureViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        SmartSecureView(content: content)
    }
}

// MARK: - Effective Screenshot Prevention
struct EffectiveScreenshotPrevention<Content: View>: UIViewRepresentable {
    let content: Content
    
    func makeUIView(context: Context) -> UIView {
        // Create the secure text field that will contain everything
        let secureField = UITextField()
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = true // FIXED: Enable user interaction to allow touch events
        secureField.backgroundColor = .clear
        secureField.borderStyle = .none
        secureField.textColor = .clear
        
        // Create SwiftUI hosting controller
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add hosting controller's view as subview to secure field
        secureField.addSubview(hostingController.view)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: secureField.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: secureField.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: secureField.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: secureField.bottomAnchor)
        ])
        
        AppLogger.log(tag: "LOG-APP: CaptureProtection", message: "EffectiveScreenshotPrevention - Content embedded in secure field with touch events enabled")
        return secureField
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let textField = uiView as? UITextField {
            textField.isSecureTextEntry = true
            textField.isUserInteractionEnabled = true // FIXED: Keep user interaction enabled
        }
    }
}

struct EffectiveScreenshotPreventionModifier: ViewModifier {
    func body(content: Content) -> some View {
        EffectiveScreenshotPrevention(content: content)
    }
}

// MARK: - View Extensions
extension View {
    /// Apply app-wide capture shield (for app root)
    func appWideCaptureShield(_ protection: CaptureProtection) -> some View {
        modifier(AppWideCaptureShield(protection: protection))
    }
    
    /// Apply per-view capture shield (full screen screenshot prevention)
    func captureShield() -> some View {
        modifier(FullScreenCaptureShield())
    }
    
    /// Apply enhanced secure view (stronger protection)
    func enhancedSecure() -> some View {
        modifier(EnhancedSecureViewModifier())
    }
    
    /// Apply standard secure view protection
    func secureFromCapture() -> some View {
        self.captureShield()
    }
    
    /// Apply smart screenshot prevention (visible during normal use, protected during capture)
    func preventScreenshots() -> some View {
        modifier(SmartSecureViewModifier())
    }
    
    /// Apply detection-only protection (no UI interference, just logging)
    func detectScreenshots() -> some View {
        self // No visual modification, just detection via CaptureProtection manager
    }
    
    /// Apply effective screenshot prevention (embeds content in secure field)
    func effectiveScreenshotBlock() -> some View {
        modifier(EffectiveScreenshotPreventionModifier())
    }
}
