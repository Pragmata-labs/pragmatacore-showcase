//
//  SiriRemoteObserver.swift
//  configurator
//
//  tvOS: Siri Remote — touch = orbit; ring up/down = zoom; center click = select.
//

import SwiftUI
import GameController

/// Siri Remote input observer. @Observable for modern SwiftUI data flow.
@Observable
final class TouchPanelObserver {
    var x: Float = 0
    var y: Float = 0
    var updateCount: Int = 0
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onClicked: (() -> Void)?

    private var isTouching = false
    private var isSetup = false

    init() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupController()
        }
        // Also try immediately in case controller is already connected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupController()
        }
    }

    private func setupController() {
        guard !isSetup, let gc = GCController.controllers().first else {
            if GCController.controllers().isEmpty { AppLog.log("Remote", "No controller found") }
            return
        }
        isSetup = true
        
        if let pad = gc.extendedGamepad {
            AppLog.log("Remote", "Extended gamepad found")
            setupExtended(pad)
        } else if let pad = gc.microGamepad {
            AppLog.log("Remote", "Micro gamepad found (old remote)")
            setupMicro(pad)
        }
    }

    private func setupExtended(_ pad: GCExtendedGamepad) {
        // Touch surface → orbit
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }
            self.isTouching = (x != 0 || y != 0)
            DispatchQueue.main.async {
                self.x = x
                self.y = y
                self.updateCount &+= 1
            }
        }

        // Ring click up/down → zoom
        pad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self, pressed, !self.isTouching else { return }
            AppLog.log("Remote", "dpad.up pressed")
            DispatchQueue.main.async { self.onZoomIn?() }
        }
        pad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self, pressed, !self.isTouching else { return }
            AppLog.log("Remote", "dpad.down pressed")
            DispatchQueue.main.async { self.onZoomOut?() }
        }

        // Center click → select
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            AppLog.log("Remote", "buttonA pressed")
            DispatchQueue.main.async { self?.onClicked?() }
        }
        
        // Play/Pause removed - handled by SwiftUI
    }
    
    private func setupMicro(_ pad: GCMicroGamepad) {
        pad.reportsAbsoluteDpadValues = true
        pad.dpad.valueChangedHandler = { [weak self] _, x, y in
            DispatchQueue.main.async {
                self?.x = x
                self?.y = y
                self?.updateCount &+= 1
            }
        }
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed, let self else { return }
            DispatchQueue.main.async {
                let y = self.y
                if y > 0.3 { self.onZoomIn?() }
                else if y < -0.3 { self.onZoomOut?() }
            }
        }
        // Play/Pause removed - handled by SwiftUI
    }
}
