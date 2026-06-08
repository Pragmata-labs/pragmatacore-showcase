/**
 * @file ViewController.swift
 * @brief Main UI controller for the 3D Boat Configurator application.
 *
 * This class coordinates between the FilamentView renderer and the UIKit-based overlay UI.
 * It manages the application state, gesture recognition, and animation triggers.
 */

import UIKit
import SwiftUI

/**
 * @class ViewController
 * @brief Controls the main 3D visualization screen and its overlay UI elements.
 */
class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    /** View hosting the Filament 3D engine. */
    private var filamentView: FilamentView!
    // UI Outlets
    private var backgroundButton: UIButton!
    private var rainButton: UIButton!
    private var frontButton: UIButton!
    private var topButton: UIButton!
    private var rearButton: UIButton!
    private var orbitSwitch: UISwitch!
    private var orbitLabel: UILabel!
    private var debugAxisSwitch: UISwitch!
    private var debugAxisLabel: UILabel!
    private var nightModeSwitch: UISwitch!
    private var nightModeLabel: UILabel!
    private var spaceEnvironmentSwitch: UISwitch!
    private var spaceEnvironmentLabel: UILabel!
    private var controlsContainer: UIView!
    private var titleLabel: UILabel!
    
    // Side menu (replaces dropdown)
    private var sideMenuContainer: UIView!
    private var sideMenuScrollView: UIScrollView!
    private var sideMenuLeadingConstraint: NSLayoutConstraint!
    private var isMenuOpen = false
    
    // Tab bar for menu
    private var menuSegmentedControl: UISegmentedControl!
    private var menuTabContainer: UIView!
    private var debugTabStackView: UIStackView!
    
    // Gesture recognizer references for priority
    private var rightMenuSwipeLeft: UISwipeGestureRecognizer!
    private var rightMenuSwipeRight: UISwipeGestureRecognizer!
    
    // Lighting controls
    private var sunLightSlider: UISlider!
    private var ambientLightSlider: UISlider!
    private var sunLightLabel: UILabel!
    private var ambientLightLabel: UILabel!
    
    // Loading overlay
    private var loadingOverlay: UIView!
    private var loadingProgressBar: UIProgressView!
    private var loadingStageLabel: UILabel!
    
    // Background color cycling
    private var backgroundColors: [ManifestLoader.HullColor] = []
    private var currentBackgroundColorIndex: Int = 0

    /**
     * Initializes the view, sets up the 3D renderer, and loads configuration.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Full screen: extend under status bar and home indicator; don’t inset layout by safe area.
        edgesForExtendedLayout = .all
        view.insetsLayoutMarginsFromSafeArea = false

        view.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        filamentView = FilamentView(frame: view.bounds)
        filamentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(filamentView, at: 0)
        
        // ========================================
        // Loading Overlay
        // ========================================
        setupLoadingOverlay()
        
        // ========================================
        // GUIKontrole: svi gumbi + orbit toggle (horizontal flow + wrap)
        // ========================================
        setupGUIKontrole()

        // ========================================
        // TITLE PREKO 3D VIEWPORTA (64pt od vrha)
        // ========================================
        setupTitle()
        
        // Load background colors asynchronously (non-blocking)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let colors = ManifestLoader.shared.loadBackgroundColors()
            DispatchQueue.main.async {
                self?.backgroundColors = colors
                self?.currentBackgroundColorIndex = 0
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        filamentView?.frame = view.bounds
        loadingOverlay?.frame = view.bounds
    }



    @objc private func orbitSwitchChanged(_ sender: UISwitch) {
        AppLog.log("ViewController", "🔧 Orbit controls switch changed: isOn=%@", sender.isOn ? "YES" : "NO")
        filamentView.pragmataView.setOrbitEnabled(sender.isOn)
        
        // Verify state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let actualState = self.filamentView.pragmataView.isOrbitEnabled()
            AppLog.log("ViewController", "🔧 Orbit controls state check: switch=%@, actual=%@", 
                  sender.isOn ? "YES" : "NO", actualState ? "YES" : "NO")
            if sender.isOn != actualState {
                AppLog.log("ViewController", "⚠️ Orbit controls state mismatch - correcting switch")
                sender.isOn = actualState
            }
        }
    }
    
    @objc private func debugAxisSwitchChanged(_ sender: UISwitch) {
        AppLog.log("ViewController", "🔧 Debug axis switch changed: isOn=%@", sender.isOn ? "YES" : "NO")
        
        // Set visibility directly based on switch state
        filamentView.pragmataView.setDebugAxisVisible(sender.isOn)
        
        // Verify state after a short delay (in case asset not loaded yet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let actualState = self.filamentView.pragmataView.isDebugAxisVisible()
            AppLog.log("ViewController", "🔧 Debug axis state check: switch=%@, actual=%@", 
                  sender.isOn ? "YES" : "NO", actualState ? "YES" : "NO")
            if actualState != sender.isOn {
                // State mismatch - update switch to match actual state
                AppLog.log("ViewController", "⚠️ Debug axis state mismatch - correcting switch")
                sender.isOn = actualState
            }
        }
    }
    
    @objc private func nightModeSwitchChanged(_ sender: UISwitch) {
        filamentView.pragmataView.setNightMode(sender.isOn)
    }

    @objc private func spaceEnvironmentSwitchChanged(_ sender: UISwitch) {
        let preset = sender.isOn ? "Space" : "Sunny"
        filamentView.pragmataView.setEnvironmentPreset(preset)
    }
    
    
    @objc private func moveToFront() {
        filamentView.pragmataView.moveToPresetFront()
        updateButtonStates(active: .front)
    }

    @objc private func moveToTop() {
        filamentView.pragmataView.moveToPresetTop()
        updateButtonStates(active: .top)
    }

    @objc private func moveToRear() {
        filamentView.pragmataView.moveToPresetRear()
        updateButtonStates(active: .rear)
    }
    
    private enum ActivePreset {
        case front, top, rear
    }
    
    private var currentActivePreset: ActivePreset = .front
    
    private func updateButtonStates(active: ActivePreset) {
        currentActivePreset = active
        // Simple iOS menu style - use font weight to show active
        let inactiveFont = UIFont.systemFont(ofSize: 17, weight: .regular)
        let activeFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        // Reset all to inactive
        frontButton.titleLabel?.font = inactiveFont
        topButton.titleLabel?.font = inactiveFont
        rearButton.titleLabel?.font = inactiveFont
        
        // Highlight active with bold font
        switch active {
        case .front:
            frontButton.titleLabel?.font = activeFont
        case .top:
            topButton.titleLabel?.font = activeFont
        case .rear:
            rearButton.titleLabel?.font = activeFont
        }
    }
    
    // ========================================
    // BACKGROUND COLOR CHANGE (cycles through JSON colors)
    // ========================================
    @objc private func changeBackgroundColor() {
        cycleToNextBackgroundColor()
    }
    
    private var isRaining = false
    
    @objc private func toggleRain() {
        isRaining.toggle()
        if isRaining {
            filamentView.pragmataView.startRain()
            rainButton.setTitle("Rain ON", for: .normal)
        } else {
            filamentView.pragmataView.stopRain()
            rainButton.setTitle("Rain", for: .normal)
        }
    }
    
    private func cycleToNextBackgroundColor() {
        guard !backgroundColors.isEmpty else {
            // Fallback to random if colors not loaded
            let red = Float.random(in: 0...1)
            let green = Float.random(in: 0...1)
            let blue = Float.random(in: 0...1)
            let alpha: Float = 1.0
            
            // Promijeni pozadinu cijele aplikacije
            view.backgroundColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
            
            // Promijeni pozadinu i 3D view-a - sve u jednom pozivu
            // PragmataView će postaviti i svoju pozadinu i PragmataView (Objective-C++) pozadinu
            filamentView.setBackgroundColor(red: red, green: green, blue: blue, alpha: alpha)
            return
        }
        
        // Safety check: ensure index is valid
        guard currentBackgroundColorIndex >= 0 && currentBackgroundColorIndex < backgroundColors.count else {
            AppLog.log("ViewController", "⚠️ Invalid background color index: %d (count: %d), resetting to 0", currentBackgroundColorIndex, backgroundColors.count)
            currentBackgroundColorIndex = 0
            return
        }
        
        // Cycle to NEXT color FIRST (so we don't re-apply the current color)
        currentBackgroundColorIndex = (currentBackgroundColorIndex + 1) % backgroundColors.count
        
        // Get the NEXT color and apply it
        let color = backgroundColors[currentBackgroundColorIndex]
        let r = Float(color.rgb.r)
        let g = Float(color.rgb.g)
        let b = Float(color.rgb.b)
        let alpha: Float = 1.0
        
        // Clamp RGB values to valid range (0.0 - 1.0)
        let clampedR = max(0.0, min(1.0, r))
        let clampedG = max(0.0, min(1.0, g))
        let clampedB = max(0.0, min(1.0, b))
        
        AppLog.log("ViewController", "🎨 Applying background color: %@ (RGB: %.3f, %.3f, %.3f) [index: %d]", color.name, clampedR, clampedG, clampedB, currentBackgroundColorIndex)
        
        // Promijeni pozadinu cijele aplikacije
        view.backgroundColor = UIColor(red: CGFloat(clampedR), green: CGFloat(clampedG), blue: CGFloat(clampedB), alpha: CGFloat(alpha))
        
        // Promijeni pozadinu i 3D view-a - sve u jednom pozivu
        // PragmataView će postaviti i svoju pozadinu i PragmataView (Objective-C++) pozadinu
        filamentView.setBackgroundColor(red: clampedR, green: clampedG, blue: clampedB, alpha: alpha)
        
    }

    // ========================================
    // TITLE SETUP
    // ========================================
    // MARK: - Loading Overlay

    private func setupLoadingOverlay() {
        loadingOverlay = UIView(frame: view.bounds)
        loadingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        loadingOverlay.backgroundColor = .black

        // App Icon logo
        let logoImageView = UIImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        if let appIcon = UIImage(named: "AppIcon") {
            logoImageView.image = appIcon
        }
        logoImageView.layer.cornerRadius = 24
        logoImageView.clipsToBounds = true
        loadingOverlay.addSubview(logoImageView)

        // Progress bar
        loadingProgressBar = UIProgressView(progressViewStyle: .default)
        loadingProgressBar.translatesAutoresizingMaskIntoConstraints = false
        loadingProgressBar.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        loadingProgressBar.progressTintColor = .white
        loadingProgressBar.progress = 0.0
        loadingOverlay.addSubview(loadingProgressBar)

        // Stage label
        loadingStageLabel = UILabel()
        loadingStageLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingStageLabel.text = "Initializing..."
        loadingStageLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        loadingStageLabel.font = .systemFont(ofSize: 14)
        loadingStageLabel.textAlignment = .center
        loadingOverlay.addSubview(loadingStageLabel)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -40),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),

            loadingProgressBar.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 32),
            loadingProgressBar.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingProgressBar.widthAnchor.constraint(equalTo: loadingOverlay.widthAnchor, multiplier: 0.6),

            loadingStageLabel.topAnchor.constraint(equalTo: loadingProgressBar.bottomAnchor, constant: 12),
            loadingStageLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
        ])

        view.addSubview(loadingOverlay)

        // Wire progress callback
        filamentView.pragmataView.loadingProgressCallback = { [weak self] progress, stage in
            guard let self else { return }
            self.loadingProgressBar.setProgress(progress, animated: true)
            self.loadingStageLabel.text = stage
            if progress >= 1.0 {
                UIView.animate(withDuration: 0.4, delay: 0.2, options: .curveEaseOut) {
                    self.loadingOverlay.alpha = 0
                } completion: { _ in
                    self.loadingOverlay.removeFromSuperview()
                }
            }
        }
    }

    private func setupTitle() {
        // Blur background za title - Apple Menu Style
        let titleBlurEffect = UIBlurEffect(style: .systemMaterial)
        let titleBlurView = UIVisualEffectView(effect: titleBlurEffect)
        titleBlurView.translatesAutoresizingMaskIntoConstraints = false
        titleBlurView.layer.cornerRadius = 20
        titleBlurView.layer.cornerCurve = .continuous
        titleBlurView.clipsToBounds = true
        view.addSubview(titleBlurView)
        
        // Title label
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Car Preview"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .label  // Adaptive color
        titleBlurView.contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleBlurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleBlurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleBlurView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleBlurView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: titleBlurView.contentView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: titleBlurView.contentView.bottomAnchor, constant: -12),
            titleLabel.leadingAnchor.constraint(equalTo: titleBlurView.contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: titleBlurView.contentView.trailingAnchor, constant: -20)
        ])
        
        // Osiguraj da naslov bude iznad 3D i gumba
        view.bringSubviewToFront(titleBlurView)
    }

    // ========================================
    // HELPER: Create iOS Menu Style Button
    // ========================================
    private func createMenuStyleButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        button.setTitleColor(.label, for: .normal)  // Adaptive text color
        button.contentHorizontalAlignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true  // Standard iOS row height
        
        // No background - clean like menu items
        button.backgroundColor = .clear
        
        return button
    }
    
    // ========================================
    // HELPER: Create Menu Separator
    // ========================================
    private func createSeparator() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: container.topAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // ========================================
    // GUIKontrole - Modern Glass UI
    // ========================================
    private func setupGUIKontrole() {
        // iOS Menu Style Buttons - Simple Text
        backgroundButton = createMenuStyleButton(title: "Background")
        backgroundButton.addTarget(self, action: #selector(changeBackgroundColor), for: .touchUpInside)
        
        rainButton = createMenuStyleButton(title: "Rain")
        rainButton.addTarget(self, action: #selector(toggleRain), for: .touchUpInside)
        
        frontButton = createMenuStyleButton(title: "Front")
        frontButton.addTarget(self, action: #selector(moveToFront), for: .touchUpInside)
        
        topButton = createMenuStyleButton(title: "Top")
        topButton.addTarget(self, action: #selector(moveToTop), for: .touchUpInside)
        
        rearButton = createMenuStyleButton(title: "Charge")
        rearButton.addTarget(self, action: #selector(moveToRear), for: .touchUpInside)
        
        orbitLabel = UILabel()
        orbitLabel.translatesAutoresizingMaskIntoConstraints = false
        orbitLabel.text = "Orbit Controls"
        orbitLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        orbitLabel.textColor = .label  // Adaptive
        
        orbitSwitch = UISwitch()
        orbitSwitch.translatesAutoresizingMaskIntoConstraints = false
        orbitSwitch.isOn = false
        orbitSwitch.isEnabled = true
        orbitSwitch.onTintColor = .systemBlue
        orbitSwitch.addTarget(self, action: #selector(orbitSwitchChanged(_:)), for: .valueChanged)
        
        let orbitStack = UIStackView(arrangedSubviews: [orbitLabel, orbitSwitch])
        orbitStack.axis = .horizontal
        orbitStack.alignment = .center
        orbitStack.spacing = 6
        orbitStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Debug Axis Toggle
        debugAxisLabel = UILabel()
        debugAxisLabel.translatesAutoresizingMaskIntoConstraints = false
        debugAxisLabel.text = "Axis"
        debugAxisLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        debugAxisLabel.textColor = .label  // Adaptive
        
        debugAxisSwitch = UISwitch()
        debugAxisSwitch.translatesAutoresizingMaskIntoConstraints = false
        debugAxisSwitch.isOn = false
        debugAxisSwitch.isEnabled = true  // Ensure switch is enabled
        debugAxisSwitch.onTintColor = .systemTeal
        debugAxisSwitch.addTarget(self, action: #selector(debugAxisSwitchChanged(_:)), for: .valueChanged)
        
        let debugAxisStack = UIStackView(arrangedSubviews: [debugAxisLabel, debugAxisSwitch])
        debugAxisStack.axis = .horizontal
        debugAxisStack.alignment = .center
        debugAxisStack.distribution = .equalSpacing
        debugAxisStack.spacing = 8
        debugAxisStack.translatesAutoresizingMaskIntoConstraints = false
        debugAxisStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        debugAxisStack.isLayoutMarginsRelativeArrangement = true
        debugAxisStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // Night Mode Toggle (will be added to debug menu)
        nightModeLabel = UILabel()
        nightModeLabel.translatesAutoresizingMaskIntoConstraints = false
        nightModeLabel.text = "Night Mode"
        nightModeLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        nightModeLabel.textColor = .label  // Adaptive
        
        nightModeSwitch = UISwitch()
        nightModeSwitch.translatesAutoresizingMaskIntoConstraints = false
        nightModeSwitch.isOn = false
        nightModeSwitch.onTintColor = .systemRed
        nightModeSwitch.addTarget(self, action: #selector(nightModeSwitchChanged(_:)), for: .valueChanged)

        spaceEnvironmentLabel = UILabel()
        spaceEnvironmentLabel.translatesAutoresizingMaskIntoConstraints = false
        spaceEnvironmentLabel.text = "Space"
        spaceEnvironmentLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        spaceEnvironmentLabel.textColor = .label

        spaceEnvironmentSwitch = UISwitch()
        spaceEnvironmentSwitch.translatesAutoresizingMaskIntoConstraints = false
        spaceEnvironmentSwitch.isOn = false
        spaceEnvironmentSwitch.onTintColor = .systemPurple
        spaceEnvironmentSwitch.addTarget(self, action: #selector(spaceEnvironmentSwitchChanged(_:)), for: .valueChanged)
        
        // Side menu will be setup in setupSideMenu() - no dropdown button needed
        
        // GUIKontrole container - Apple Menu Style Blur
        let blurEffect = UIBlurEffect(style: .systemMaterial)  // Adaptive light/dark
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 24  // More rounded like iOS menus
        blurView.layer.cornerCurve = .continuous  // Apple's smooth corners
        blurView.clipsToBounds = true
        
        view.addSubview(blurView)
        
        controlsContainer = blurView.contentView
        
        // Vertical list like iOS menu
        let verticalStack = UIStackView()
        verticalStack.axis = .vertical
        verticalStack.alignment = .fill
        verticalStack.spacing = 0  // No spacing - separators handle it
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(verticalStack)
        
        // Camera buttons in horizontal row
        let cameraRow = UIStackView(arrangedSubviews: [frontButton, topButton, rearButton])
        cameraRow.axis = .horizontal
        cameraRow.distribution = .fillEqually
        cameraRow.spacing = 1  // Minimal spacing between buttons
        cameraRow.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to vertical stack with separators (Debug Axis removed - now in Options menu)
        verticalStack.addArrangedSubview(cameraRow)
        verticalStack.addArrangedSubview(createSeparator())
        
        // Background and Rain in horizontal row (50/50 split)
        let weatherRow = UIStackView(arrangedSubviews: [backgroundButton, rainButton])
        weatherRow.axis = .horizontal
        weatherRow.distribution = .fillEqually
        weatherRow.spacing = 1
        weatherRow.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.addArrangedSubview(weatherRow)
        
        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurView.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),  // Min width like iOS menu
            blurView.widthAnchor.constraint(lessThanOrEqualToConstant: 350),  // Max width
            blurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            verticalStack.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 8),
            verticalStack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            verticalStack.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            verticalStack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -8)
        ])
        
        // Inicijalno stanje gumba
        updateButtonStates(active: .front)
        
        // Setup side menu
        setupSideMenu()
        
        // Setup swipe gestures for menu
        setupSwipeGesture()
    }
    
    // ========================================
    // MARK: - Side Menu Setup
    // ========================================

    private func setupSideMenu() {
        // Container with blur background
        sideMenuContainer = UIView()
        sideMenuContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.55)
        sideMenuContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Blur effect with higher intensity
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.alpha = 1.0 // Full opacity for blur
        blurView.translatesAutoresizingMaskIntoConstraints = false
        sideMenuContainer.addSubview(blurView)
        
        // Scroll view for menu content
        sideMenuScrollView = UIScrollView()
        sideMenuScrollView.translatesAutoresizingMaskIntoConstraints = false
        sideMenuScrollView.showsVerticalScrollIndicator = true
        sideMenuScrollView.alwaysBounceVertical = true
        
        blurView.contentView.addSubview(sideMenuScrollView)
        view.addSubview(sideMenuContainer)
        
        // Set high z-index so side menu is above all other elements (including debug view)
        sideMenuContainer.layer.zPosition = 2000
        sideMenuContainer.isUserInteractionEnabled = true
        
        // Constraints
        sideMenuLeadingConstraint = sideMenuContainer.leadingAnchor.constraint(equalTo: view.trailingAnchor)
        
        // Tab bar container
        menuTabContainer = UIView()
        menuTabContainer.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(menuTabContainer)
        
        // Segmented control for tabs (DEBUG only now)
        menuSegmentedControl = UISegmentedControl(items: ["DEBUG"])
        menuSegmentedControl.selectedSegmentIndex = 0
        menuSegmentedControl.addTarget(self, action: #selector(menuTabChanged(_:)), for: .valueChanged)
        menuSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        menuTabContainer.addSubview(menuSegmentedControl)
        
        // Stack views for each tab
        debugTabStackView = UIStackView()
        debugTabStackView.axis = .vertical
        debugTabStackView.spacing = 12
        debugTabStackView.translatesAutoresizingMaskIntoConstraints = false
        debugTabStackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        debugTabStackView.isLayoutMarginsRelativeArrangement = true
        
        sideMenuScrollView.addSubview(debugTabStackView)
        
        NSLayoutConstraint.activate([
            // Container - start below title (safeArea + ~80pt for title)
            sideMenuLeadingConstraint,
            sideMenuContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            sideMenuContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            sideMenuContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            
            // Blur
            blurView.topAnchor.constraint(equalTo: sideMenuContainer.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: sideMenuContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: sideMenuContainer.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: sideMenuContainer.bottomAnchor),
            
            // Tab container
            menuTabContainer.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            menuTabContainer.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            menuTabContainer.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            menuTabContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Segmented control
            menuSegmentedControl.centerXAnchor.constraint(equalTo: menuTabContainer.centerXAnchor),
            menuSegmentedControl.centerYAnchor.constraint(equalTo: menuTabContainer.centerYAnchor),
            menuSegmentedControl.widthAnchor.constraint(equalTo: menuTabContainer.widthAnchor, multiplier: 0.9),
            
            // Scroll view - below tab bar
            sideMenuScrollView.topAnchor.constraint(equalTo: menuTabContainer.bottomAnchor),
            sideMenuScrollView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            sideMenuScrollView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            sideMenuScrollView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            
            // Debug tab stack view - pinned to top, no bottom constraint (allows scrolling)
            debugTabStackView.topAnchor.constraint(equalTo: sideMenuScrollView.topAnchor),
            debugTabStackView.leadingAnchor.constraint(equalTo: sideMenuScrollView.leadingAnchor),
            debugTabStackView.trailingAnchor.constraint(equalTo: sideMenuScrollView.trailingAnchor),
            debugTabStackView.widthAnchor.constraint(equalTo: sideMenuScrollView.widthAnchor)
            // NO bottom constraint - stack view height is determined by content
        ])
        
        // Build menu content
        buildDebugTabContent()
        
        // Add low priority bottom constraint to allow scrolling when content is larger
        let debugBottom = debugTabStackView.bottomAnchor.constraint(equalTo: sideMenuScrollView.bottomAnchor)
        debugBottom.priority = UILayoutPriority(250) // Low priority - allows stack view to be taller
        debugBottom.isActive = true
        
        // Force layout update to ensure scroll view content size is calculated
        DispatchQueue.main.async { [weak self] in
            self?.updateScrollViewContentSize()
        }
    }
    
    @objc private func menuTabChanged(_ sender: UISegmentedControl) {
        // Only DEBUG tab now, no switching needed
        
        // Update scroll view content size after tab change
        DispatchQueue.main.async { [weak self] in
            self?.updateScrollViewContentSize()
        }
    }
    
    private func updateScrollViewContentSize() {
        view.layoutIfNeeded()

        // Calculate content height from debug stack view's arranged subviews
        var contentHeight: CGFloat = 0
        for arrangedSubview in debugTabStackView.arrangedSubviews {
            arrangedSubview.layoutIfNeeded()
            contentHeight += arrangedSubview.frame.height
        }
        // Add spacing between items
        contentHeight += CGFloat(max(0, debugTabStackView.arrangedSubviews.count - 1)) * debugTabStackView.spacing
        // Add layout margins
        contentHeight += debugTabStackView.layoutMargins.top + debugTabStackView.layoutMargins.bottom

        // Set content size - must be at least as tall as scroll view frame
        let minHeight = sideMenuScrollView.frame.height > 0 ? sideMenuScrollView.frame.height : 400
        sideMenuScrollView.contentSize = CGSize(
            width: sideMenuScrollView.frame.width > 0 ? sideMenuScrollView.frame.width : 300,
            height: max(contentHeight, minHeight)
        )
    }
    
    private func setupSwipeGesture() {
        // Swipe from right edge to open menu (only from right 50pt of screen)
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft(_:)))
        swipeLeft.direction = .left
        swipeLeft.numberOfTouchesRequired = 1
        swipeLeft.delegate = self
        view.addGestureRecognizer(swipeLeft)
        
        // Swipe right anywhere to close menu
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight(_:)))
        swipeRight.direction = .right
        swipeRight.numberOfTouchesRequired = 1
        swipeRight.delegate = self
        view.addGestureRecognizer(swipeRight)
        
        // Store references for priority setup
        rightMenuSwipeLeft = swipeLeft
        rightMenuSwipeRight = swipeRight
    }
    
    @objc private func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
        let location = gesture.location(in: view)
        let screenWidth = view.bounds.width
        // Only open if swipe started from right edge (last 50pt)
        if location.x > screenWidth - 50 {
            openMenu()
        }
    }
    
    @objc private func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
        // Close right menu if open
        if isMenuOpen {
            closeMenu()
        }
    }
    
    private func openMenu() {
        guard !isMenuOpen else { return }
        isMenuOpen = true
        
        sideMenuLeadingConstraint.isActive = false
        sideMenuLeadingConstraint = sideMenuContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        sideMenuLeadingConstraint.isActive = true
        
        // Disable all buttons when menu opens
        setAllButtonsEnabled(false)
        
        // Disable orbit gestures when menu is open (prevents conflict with swipe gestures)
        filamentView.pragmataView.setOrbitGesturesEnabled(false)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func closeMenu() {
        guard isMenuOpen else { return }
        isMenuOpen = false
        
        sideMenuLeadingConstraint.isActive = false
        sideMenuLeadingConstraint = sideMenuContainer.leadingAnchor.constraint(equalTo: view.trailingAnchor)
        sideMenuLeadingConstraint.isActive = true
        
        // Enable all buttons when menu closes
        setAllButtonsEnabled(true)
        
        // Re-enable orbit gestures when menu closes (if orbit is enabled)
        if filamentView.pragmataView.isOrbitEnabled() {
            filamentView.pragmataView.setOrbitGesturesEnabled(true)
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setAllButtonsEnabled(_ enabled: Bool) {
        frontButton?.isEnabled = enabled
        topButton?.isEnabled = enabled
        rearButton?.isEnabled = enabled
        backgroundButton?.isEnabled = enabled
        controlsContainer?.isUserInteractionEnabled = enabled
        sideMenuContainer?.isUserInteractionEnabled = true
        sideMenuScrollView?.isUserInteractionEnabled = true
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    
    // MARK: - Removed: Left Telemetry Menu (animations now in right menu TELEMETRY tab)
    
    // Old left menu code removed - animations are now in right menu TELEMETRY tab
    
    private func buildDebugTabContent() {
        // Clear existing content
        debugTabStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 1. Info (at top)
        addDebugButton(title: "Info") { [weak self] in
            self?.showInfo()
        }
        debugTabStackView.addArrangedSubview(createMenuSeparator())
        
        // 2. Camera section
        addDebugSection(title: "Camera")
        // Orbit Controls Toggle Switch
        // Ensure orbitSwitch is initialized and enabled
        if orbitSwitch == nil {
            orbitSwitch = UISwitch()
            orbitSwitch.translatesAutoresizingMaskIntoConstraints = false
            orbitSwitch.onTintColor = .systemBlue
            orbitSwitch.addTarget(self, action: #selector(orbitSwitchChanged(_:)), for: .valueChanged)
        }
        if orbitLabel == nil {
            orbitLabel = UILabel()
            orbitLabel.translatesAutoresizingMaskIntoConstraints = false
            orbitLabel.text = "Orbit Controls"
            orbitLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            orbitLabel.textColor = .label
        }
        orbitSwitch.isEnabled = true  // Always enabled in debug menu
        
        let orbitStack = UIStackView(arrangedSubviews: [orbitLabel, orbitSwitch])
        orbitStack.axis = .horizontal
        orbitStack.alignment = .center
        orbitStack.distribution = .equalSpacing
        orbitStack.spacing = 8
        orbitStack.translatesAutoresizingMaskIntoConstraints = false
        orbitStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        orbitStack.isLayoutMarginsRelativeArrangement = true
        orbitStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        debugTabStackView.addArrangedSubview(orbitStack)
        addDebugButton(title: "Reset Camera") { [weak self] in
            self?.resetCamera()
        }
        debugTabStackView.addArrangedSubview(createMenuSeparator())
        
        // 3. Debug section
        addDebugSection(title: "Debug")
        // Debug Axis Toggle Switch (not button)
        let debugAxisStack = UIStackView(arrangedSubviews: [debugAxisLabel, debugAxisSwitch])
        debugAxisStack.axis = .horizontal
        debugAxisStack.alignment = .center
        debugAxisStack.distribution = .equalSpacing
        debugAxisStack.spacing = 8
        debugAxisStack.translatesAutoresizingMaskIntoConstraints = false
        debugAxisStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        debugAxisStack.isLayoutMarginsRelativeArrangement = true
        debugAxisStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        debugTabStackView.addArrangedSubview(debugAxisStack)
        addDebugButton(title: "Inspect Materials") { [weak self] in
            self?.inspectMaterials()
        }
        debugTabStackView.addArrangedSubview(createMenuSeparator())
        
        // Night Mode section
        addDebugSection(title: "Night Mode")
        let nightModeStack = UIStackView(arrangedSubviews: [nightModeLabel, nightModeSwitch])
        nightModeStack.axis = .horizontal
        nightModeStack.alignment = .center
        nightModeStack.distribution = .equalSpacing
        nightModeStack.spacing = 8
        nightModeStack.translatesAutoresizingMaskIntoConstraints = false
        nightModeStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        nightModeStack.isLayoutMarginsRelativeArrangement = true
        nightModeStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        debugTabStackView.addArrangedSubview(nightModeStack)
        debugTabStackView.addArrangedSubview(createMenuSeparator())

        // Environment section
        addDebugSection(title: "Environment")
        let spaceStack = UIStackView(arrangedSubviews: [spaceEnvironmentLabel, spaceEnvironmentSwitch])
        spaceStack.axis = .horizontal
        spaceStack.alignment = .center
        spaceStack.distribution = .equalSpacing
        spaceStack.spacing = 8
        spaceStack.translatesAutoresizingMaskIntoConstraints = false
        spaceStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        spaceStack.isLayoutMarginsRelativeArrangement = true
        spaceStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        debugTabStackView.addArrangedSubview(spaceStack)
        debugTabStackView.addArrangedSubview(createMenuSeparator())
        
        // 7. Anti-Aliasing section (moved to bottom)
        addDebugSection(title: "Anti-Aliasing")
        addDebugButton(title: "FXAA On") { [weak self] in
            self?.setFXAAEnabled(true)
        }
        addDebugButton(title: "FXAA Off") { [weak self] in
            self?.setFXAAEnabled(false)
        }
        addDebugButton(title: "MSAA 2×") { [weak self] in
            self?.setMSAAEnabled(true, sampleCount: 2)
        }
        addDebugButton(title: "MSAA 4×") { [weak self] in
            self?.setMSAAEnabled(true, sampleCount: 4)
        }
        addDebugButton(title: "MSAA Off") { [weak self] in
            self?.setMSAAEnabled(false, sampleCount: 1)
        }
        debugTabStackView.addArrangedSubview(createMenuSeparator())
        
        // 8. Resolution section (moved to bottom)
        addDebugSection(title: "Resolution")
        addDebugButton(title: "Native (1.0×)") { [weak self] in
            self?.setResolutionPreset(.native)
        }
        addDebugButton(title: "High (0.7×)") { [weak self] in
            self?.setResolutionPreset(.high)
        }
        addDebugButton(title: "Half (0.5×)") { [weak self] in
            self?.setResolutionPreset(.half)
        }
        addDebugButton(title: "Third (0.33×)") { [weak self] in
            self?.setResolutionPreset(.third)
        }
        debugTabStackView.addArrangedSubview(createMenuSeparator())
        
        // 8. Light Controls section (at bottom)
        addDebugSection(title: "Light Controls")
        
        // Sun Light Slider
        sunLightLabel = UILabel()
        sunLightLabel.text = "Sun Light"
        sunLightLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        sunLightLabel.textColor = .label
        debugTabStackView.addArrangedSubview(sunLightLabel)
        
        sunLightSlider = UISlider()
        sunLightSlider.minimumValue = 0.0
        sunLightSlider.maximumValue = 200000.0
        sunLightSlider.value = 110000.0
        sunLightSlider.addTarget(self, action: #selector(sunLightChanged(_:)), for: .valueChanged)
        sunLightSlider.translatesAutoresizingMaskIntoConstraints = false
        debugTabStackView.addArrangedSubview(sunLightSlider)
        
        // Ambient Light Slider
        ambientLightLabel = UILabel()
        ambientLightLabel.text = "Ambient Light"
        ambientLightLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        ambientLightLabel.textColor = .label
        debugTabStackView.addArrangedSubview(ambientLightLabel)
        
        ambientLightSlider = UISlider()
        ambientLightSlider.minimumValue = 0.0
        ambientLightSlider.maximumValue = 1.0
        ambientLightSlider.value = 0.63  // Initial value (will be updated when IBL loads)
        ambientLightSlider.addTarget(self, action: #selector(ambientLightChanged(_:)), for: .valueChanged)
        ambientLightSlider.translatesAutoresizingMaskIntoConstraints = false
        debugTabStackView.addArrangedSubview(ambientLightSlider)
        
        // Initialize debug axis switch state
        // Note: This might be called before asset is loaded, so state might be false initially
        if let debugAxisSwitch = debugAxisSwitch {
            let currentState = filamentView.pragmataView.isDebugAxisVisible()
            debugAxisSwitch.isOn = currentState
            debugAxisSwitch.isEnabled = true  // Ensure switch is always enabled (it's in the menu)
            AppLog.log("ViewController", "🔧 Debug axis switch initialized: isOn=%@, actualState=%@, enabled=YES", 
                  debugAxisSwitch.isOn ? "YES" : "NO", currentState ? "YES" : "NO")
        }
        
        // Initialize orbit controls switch state
        if let orbitSwitch = orbitSwitch {
            let currentState = filamentView.pragmataView.isOrbitEnabled()
            orbitSwitch.isOn = currentState
            orbitSwitch.isEnabled = true
            AppLog.log("ViewController", "🔧 Orbit controls switch initialized: isOn=%@, actualState=%@, enabled=YES", 
                  orbitSwitch.isOn ? "YES" : "NO", currentState ? "YES" : "NO")
        }
        
        // Initialize ambient light slider with current value
        if let ambientLightSlider = ambientLightSlider {
            ambientLightSlider.value = Float(filamentView.pragmataView.getAmbientLightIntensity())
        }
        
        // Update scroll view content size after content is built
        DispatchQueue.main.async { [weak self] in
            self?.updateScrollViewContentSize()
        }
    }
    
    
    private func addDebugSection(title: String) {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        debugTabStackView.addArrangedSubview(label)
    }
    
    private func addDebugButton(title: String, action: @escaping () -> Void) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.titleLabel?.numberOfLines = 0 // Allow text wrapping
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.contentHorizontalAlignment = .left
        button.addAction(UIAction { _ in
            action()
        }, for: .touchUpInside)
        debugTabStackView.addArrangedSubview(button)
    }
    
    
    
    private func createMenuSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }
    
    // ========================================
    // ORIENTATION SUPPORT - ALL ORIENTATIONS
    // ========================================
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    @objc private func resetCamera() {
        filamentView.pragmataView.moveToPresetFront()
        updateButtonStates(active: .front)
        // Orbit controls removed from UI
        AppLog.log("ViewController", "Camera reset to Front preset")
    }
    
    @objc private func inspectMaterials() {
        AppLog.log("ViewController", "🔍 Inspecting materials...")
        filamentView.pragmataView.inspectMaterials()
    }
    
    private func setResolutionPreset(_ preset: ResolutionPreset) {
        filamentView.pragmataView.setResolutionPreset(preset)
        
        let presetName: String
        switch preset {
        case .native:
            presetName = "Native (1.0×)"
        case .high:
            presetName = "High (0.7×)"
        case .half:
            presetName = "Half (0.5×)"
        case .third:
            presetName = "Third (0.33×)"
        @unknown default:
            presetName = "Unknown"
        }
        
        AppLog.log("ViewController", "Resolution preset: %@", presetName)
        
        let alert = UIAlertController(title: "Resolution", 
                                      message: presetName, 
                                      preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            alert.dismiss(animated: true)
        }
    }
    
    private func setFXAAEnabled(_ enabled: Bool) {
        filamentView.pragmataView.setAntiAliasingFXAA(enabled)
        let status = enabled ? "Enabled" : "Disabled"
        AppLog.log("ViewController", "FXAA: %@", status)
        
        let alert = UIAlertController(title: "Anti-Aliasing", 
                                      message: "FXAA \(status)", 
                                      preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            alert.dismiss(animated: true)
        }
    }
    
    private func setMSAAEnabled(_ enabled: Bool, sampleCount: Int) {
        filamentView.pragmataView.setAntiAliasingMSAA(enabled, sampleCount: Int32(sampleCount))
        let status = enabled ? "\(sampleCount)× Enabled" : "Disabled"
        AppLog.log("ViewController", "MSAA: %@", status)

        let alert = UIAlertController(title: "Anti-Aliasing",
                                      message: "MSAA \(status)",
                                      preferredStyle: .alert)
        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            alert.dismiss(animated: true)
        }
    }

    // MARK: - Light Sliders (Debug Only)
    
    @objc private func sunLightChanged(_ sender: UISlider) {
        // Sun light can update more frequently (it's less expensive)
        filamentView.pragmataView.setSunLightIntensity(sender.value)
    }
    
    @objc private func ambientLightChanged(_ sender: UISlider) {
        // Update immediately (no throttling) - LightingManager has its own threshold
        filamentView.pragmataView.setAmbientLightIntensity(sender.value)
    }
    
    @objc private func showInfo() {
        let alert = UIAlertController(title: "Car Preview", 
                                      message: "iOS 3D car viewer powered by:\n\nGoogle Filament (Rendering)\nCore3D Engine (Animation & Camera)\n\nUse camera presets to change view\nPlay animations from Options menu\nToggle Debug Axis for reference", 
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    

}
