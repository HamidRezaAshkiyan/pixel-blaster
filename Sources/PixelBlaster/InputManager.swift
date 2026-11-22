import AppKit
import CoreHaptics
import GameController
import SpriteKit

enum AimMode {
    case mouse
    case controller
}

final class InputManager {
    private(set) var activeController: GCController?
    private(set) var controllerName: String?
    private(set) var aimMode: AimMode = .mouse

    // Haptics
    private var hapticEngine: CHHapticEngine?

    // Keyboard & mouse state
    private var pressedKeys: Set<UInt16> = []
    var mouseScenePosition: CGPoint = .zero
    var isMouseDown: Bool = false

    // Edge-triggered actions (consumed each frame)
    private(set) var dashPressed: Bool = false
    private(set) var nextWeaponPressed: Bool = false
    private(set) var prevWeaponPressed: Bool = false
    private(set) var directWeaponSlot: Int? = nil
    private(set) var confirmPressed: Bool = false
    private(set) var cancelPressed: Bool = false
    private(set) var pausePressed: Bool = false
    private(set) var mutePressed: Bool = false
    private(set) var menuNavX: Int = 0
    private(set) var menuNavY: Int = 0

    // Previous button states for edge detection on controller
    private var prevDash = false
    private var prevNextWeapon = false
    private var prevPrevWeapon = false
    private var prevConfirm = false
    private var prevCancel = false
    private var prevPause = false
    private var menuNavCooldown: TimeInterval = 0

    // Callbacks
    var onControllerStatusChanged: ((String?) -> Void)?

    // Persistent last valid right-stick aim angle
    private(set) var controllerAimAngle: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        GCController.startWirelessControllerDiscovery(completionHandler: nil)

        if let existing = GCController.controllers().first {
            attachController(existing)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        hapticEngine?.stop(completionHandler: nil)
    }

    @objc private func handleControllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        DispatchQueue.main.async { [weak self] in
            self?.attachController(controller)
        }
    }

    @objc private func handleControllerDisconnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.activeController == controller {
                self.hapticEngine?.stop(completionHandler: nil)
                self.hapticEngine = nil
                self.activeController = nil
                self.controllerName = nil
                self.aimMode = .mouse
                if let another = GCController.controllers().first(where: { $0 != controller }) {
                    self.attachController(another)
                } else {
                    self.onControllerStatusChanged?(nil)
                }
            }
        }
    }

    private func attachController(_ controller: GCController) {
        activeController = controller
        controllerName = controller.vendorName ?? "Game Controller"
        aimMode = .controller
        setupHaptics(for: controller)
        onControllerStatusChanged?(controllerName)
    }

    private func setupHaptics(for controller: GCController) {
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        guard let haptics = controller.haptics,
              let engine = haptics.createEngine(withLocality: .default) else { return }
        engine.playsHapticsOnly = true
        engine.resetHandler = { [weak engine] in
            try? engine?.start()
        }
        try? engine.start()
        hapticEngine = engine
    }

    func playHaptic(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.05, min(1.0, intensity)))
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0.05, min(1.0, sharpness)))
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: duration
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are optional; ignore errors on unsupported devices
        }
    }

    // MARK: - Keyboard & Mouse Events

    func keyDown(_ event: NSEvent) {
        let code = event.keyCode
        let isRepeat = event.isARepeat
        pressedKeys.insert(code)

        if !isRepeat {
            switch code {
            case 49, 56, 60: // Space, Left/Right Shift
                dashPressed = true
            case 14: // E
                nextWeaponPressed = true
            case 12: // Q
                prevWeaponPressed = true
            case 18: directWeaponSlot = 0 // 1
            case 19: directWeaponSlot = 1 // 2
            case 20: directWeaponSlot = 2 // 3
            case 21: directWeaponSlot = 3 // 4
            case 36, 76: // Return / Enter
                confirmPressed = true
            case 53: // Escape
                pausePressed = true
                cancelPressed = true
            case 46: // M
                mutePressed = true
            case 123, 0: // Left / A
                menuNavX = -1
            case 124, 2: // Right / D
                menuNavX = 1
            case 126, 13: // Up / W
                menuNavY = -1
            case 125, 1: // Down / S
                menuNavY = 1
            default:
                break
            }
        }
    }

    func keyUp(_ event: NSEvent) {
        pressedKeys.remove(event.keyCode)
    }

    func mouseMoved(to scenePoint: CGPoint) {
        mouseScenePosition = scenePoint
        aimMode = .mouse
    }

    // MARK: - Per-Frame Polling

    var moveVector: CGVector {
        var dx: CGFloat = 0
        var dy: CGFloat = 0

        // Keyboard WASD + Arrow keys
        if pressedKeys.contains(0) || pressedKeys.contains(123) { dx -= 1 } // A / Left
        if pressedKeys.contains(2) || pressedKeys.contains(124) { dx += 1 } // D / Right
        if pressedKeys.contains(13) || pressedKeys.contains(126) { dy += 1 } // W / Up
        if pressedKeys.contains(1) || pressedKeys.contains(125) { dy -= 1 } // S / Down

        // Controller Left Stick + D-Pad
        if let pad = activeController?.extendedGamepad {
            let lx = CGFloat(pad.leftThumbstick.xAxis.value)
            let ly = CGFloat(pad.leftThumbstick.yAxis.value)
            let mag = hypot(lx, ly)
            if mag > 0.16 {
                dx += lx
                dy += ly
            } else {
                if pad.dpad.left.isPressed { dx -= 1 }
                if pad.dpad.right.isPressed { dx += 1 }
                if pad.dpad.up.isPressed { dy += 1 }
                if pad.dpad.down.isPressed { dy -= 1 }
            }
        }

        let len = hypot(dx, dy)
        if len > 1.0 {
            return CGVector(dx: dx / len, dy: dy / len)
        }
        return CGVector(dx: dx, dy: dy)
    }

    var isFiring: Bool {
        if isMouseDown { return true }
        if let pad = activeController?.extendedGamepad {
            if pad.rightTrigger.value > 0.2 || pad.rightShoulder.isPressed {
                return true
            }
        }
        return false
    }

    func pollController(dt: TimeInterval) {
        if menuNavCooldown > 0 {
            menuNavCooldown -= dt
        }

        guard let pad = activeController?.extendedGamepad else { return }

        // Right stick aim
        let rx = CGFloat(pad.rightThumbstick.xAxis.value)
        let ry = CGFloat(pad.rightThumbstick.yAxis.value)
        if hypot(rx, ry) > 0.2 {
            controllerAimAngle = atan2(ry, rx)
            aimMode = .controller
        }

        // Edge-triggered buttons
        let dashNow = pad.leftTrigger.value > 0.25 || pad.buttonA.isPressed
        if dashNow && !prevDash { dashPressed = true }
        prevDash = dashNow

        let nextWepNow = pad.buttonX.isPressed || pad.leftShoulder.isPressed
        if nextWepNow && !prevNextWeapon { nextWeaponPressed = true }
        prevNextWeapon = nextWepNow

        let prevWepNow = pad.buttonY.isPressed
        if prevWepNow && !prevPrevWeapon { prevWeaponPressed = true }
        prevPrevWeapon = prevWepNow

        let confirmNow = pad.buttonA.isPressed
        if confirmNow && !prevConfirm { confirmPressed = true }
        prevConfirm = confirmNow

        let cancelNow = pad.buttonB.isPressed
        if cancelNow && !prevCancel { cancelPressed = true }
        prevCancel = cancelNow

        let pauseNow = pad.buttonMenu.isPressed
        if pauseNow && !prevPause { pausePressed = true }
        prevPause = pauseNow

        // Menu navigation via Left Stick or D-Pad
        if menuNavCooldown <= 0 {
            var navX = 0
            var navY = 0
            if pad.dpad.left.isPressed || pad.leftThumbstick.xAxis.value < -0.55 { navX = -1 }
            else if pad.dpad.right.isPressed || pad.leftThumbstick.xAxis.value > 0.55 { navX = 1 }

            if pad.dpad.up.isPressed || pad.leftThumbstick.yAxis.value > 0.55 { navY = -1 }
            else if pad.dpad.down.isPressed || pad.leftThumbstick.yAxis.value < -0.55 { navY = 1 }

            if navX != 0 || navY != 0 {
                menuNavX = navX
                menuNavY = navY
                menuNavCooldown = 0.20
            }
        }
    }

    func endFrame() {
        dashPressed = false
        nextWeaponPressed = false
        prevWeaponPressed = false
        directWeaponSlot = nil
        confirmPressed = false
        cancelPressed = false
        pausePressed = false
        mutePressed = false
        menuNavX = 0
        menuNavY = 0
    }
}
