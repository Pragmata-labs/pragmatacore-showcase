/**
 * @file TopViewButton.swift
 * @brief Reusable button component for animation controls.
 *
 * This component is optimized for "Top View" interaction, featuring a 
 * 48x48px visible fill area inside a 64x64px touch trigger area for 
 * improved ergonomics.
 */

import UIKit

/**
 * @class TopViewButton
 * @brief Circular button used for car part animations (Doors, Hood, etc.).
 */
class TopViewButton: UIButton {
    
    // MARK: - Properties
    
    /** Unique identifier for the button (e.g., "LFD", "RFD"). */
    var buttonId: String = ""
    /** Name of the GLTF animation this button triggers. */
    var animationName: String = ""
    /** Boolean indicating if the button behaves as a persistent toggle. */
    var isToggle: Bool = false
    /** Private view representing the circular background. */
    private var fillAreaView: UIView!
    
    // MARK: - Initialization
    
    /**
     * Initializes a new top-view button.
     * 
     * @param buttonId      The identifier used for state tracking.
     * @param label         Short text displayed on the button.
     * @param animationName The internal name of the model animation.
     */
    init(buttonId: String, label: String, animationName: String) {
        super.init(frame: .zero)
        self.buttonId = buttonId
        self.animationName = animationName
        setupButton(label: label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    /**
     * Configures the visual appearance and hit-testing hierarchy.
     */
    private func setupButton(label: String) {
        // Fill area: 48x48px (visible button area)
        let fillSize: CGFloat = 48.0
        
        // Trigger area: 64x64px (hit area - larger than fill area)
        let triggerSize: CGFloat = 64.0
        
        // Set button frame to trigger size for hit area
        self.frame = CGRect(x: 0, y: 0, width: triggerSize, height: triggerSize)
        
        // Button background is transparent (only fill area is visible)
        self.backgroundColor = .clear
        
        // Create fill area view (48x48px, centered in 64x64px button)
        // Use adaptive system background color that changes with light/dark mode
        let fillAreaView = UIView()
        fillAreaView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
        fillAreaView.layer.cornerRadius = fillSize / 2
        fillAreaView.clipsToBounds = true
        fillAreaView.isUserInteractionEnabled = false // Don't block touch events
        fillAreaView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(fillAreaView)
        
        // Store reference to fillAreaView for trait collection updates
        self.fillAreaView = fillAreaView
        
        // Center fill area in button (48x48 centered in 64x64)
        NSLayoutConstraint.activate([
            fillAreaView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            fillAreaView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            fillAreaView.widthAnchor.constraint(equalToConstant: fillSize),
            fillAreaView.heightAnchor.constraint(equalToConstant: fillSize)
        ])
        
        // Register for trait changes (iOS 17.0+)
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (sender: TopViewButton, previousTraitCollection: UITraitCollection) in
                // Update fill area background color when switching between light/dark mode
                self?.fillAreaView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
            }
        }
        
        // Add label (centered in fill area)
        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        labelView.textColor = .label
        labelView.textAlignment = .center
        labelView.isUserInteractionEnabled = false // Don't block touch events
        labelView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(labelView)
        
        // Center label in fill area
        NSLayoutConstraint.activate([
            labelView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            labelView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            labelView.widthAnchor.constraint(lessThanOrEqualToConstant: fillSize - 8),
            labelView.heightAnchor.constraint(lessThanOrEqualToConstant: fillSize - 8)
        ])
        
        // Add tap feedback
        self.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    /**
     * Internal tap handler for visual feedback (shrink animation).
     */
    @objc private func buttonTapped() {
        // Visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }
    
    // MARK: - Override hit test for larger trigger area
    
    /**
     * Standard hit test check. Note: Button frame is explicitly 64x64.
     */
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Button frame is already 64x64, so default hit test should work
        return super.point(inside: point, with: event)
    }
    
    // MARK: - Trait Collection Updates (for light/dark mode)
    
    /**
     * Legacy handler for light/dark mode changes on iOS < 17.0.
     */
    @available(iOS, deprecated: 17.0, message: "Use registerForTraitChanges instead")
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Only handle on iOS < 17.0 (iOS 17.0+ uses registerForTraitChanges)
        if #unavailable(iOS 17.0) {
            // Update fill area background color when switching between light/dark mode
            if let previousTraitCollection = previousTraitCollection,
               traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                fillAreaView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
            }
        }
    }
}

