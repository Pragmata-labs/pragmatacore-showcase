/**
 * @file FilamentView.swift
 * @brief Swift wrapper for the Objective-C++ PragmataView.
 *
 * This module acts as an interface between the Swift UI code and the 
 * underlying C++/Filament rendering logic defined in PragmataView.
 */

import UIKit

/**
 * @class FilamentView
 * @brief UIView subclass that hosts the PragmataView renderer.
 *
 * It manages the lifecycle of the PragmataView and provides public methods 
 * for configuration from Swift.
 */
class FilamentView: UIView {
    // Objective-C++ PragmataView klasa (importirana kroz bridging header)
    private var renderer: PragmataView!
    
    /**
     * Public access to the underlying PragmataView instance.
     */
    var pragmataView: PragmataView {
        return renderer
    }
    
    /**
     * Sets the background color of both the Swift view and the Filament renderer.
     * 
     * @param red   Red component (0.0 - 1.0).
     * @param green Green component (0.0 - 1.0).
     * @param blue  Blue component (0.0 - 1.0).
     * @param alpha Alpha component (0.0 - 1.0).
     */
    func setBackgroundColor(red: Float, green: Float, blue: Float, alpha: Float) {
        // Postavi pozadinu ovog view-a da match-a parent view
        self.backgroundColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
        
        // Postavi i PragmataView pozadinu
        renderer.setBackgroundColorRed(red, green: green, blue: blue, alpha: alpha)
    }
    
    /**
     * Initializes the view with a frame.
     */
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    /**
     * Initializes the view from a coder (Storyboard/XIB).
     */
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    /**
     * Internal setup method to initialize the renderer and appearance.
     */
    private func setup() {
        self.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.clipsToBounds = true
        
        // ========================================
        // KREIRANJE PRAGMATA VIEW-A
        // ========================================
        // bounds = veličina ovog view-a (koju smo dobili iz ViewController-a)
        // PragmataView (Objective-C++) će koristiti tu veličinu za MTKView i Filament viewport
        // Swift će koristiti Objective-C klasu jer je u bridging headeru
        renderer = PragmataView(frame: bounds)
        
        // Autoresizing mask = automatski se prilagođava veličini parent view-a
        // Kao CSS: width: 100%, height: 100%
        renderer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(renderer)
        
    }
    
    // ========================================
    // AUTOMATSKO PRAĆENJE PROMJENA VELIČINE
    // ========================================
    /**
     * Called when the view's layout changes (e.g., orientation).
     */
    override func layoutSubviews() {
        super.layoutSubviews()
        // PragmataView će automatski detektovati promjenu jer koristi self.bounds
        // i jer je delegate za MTKView koji poziva mtkView:drawableSizeWillChange:
    }
}





