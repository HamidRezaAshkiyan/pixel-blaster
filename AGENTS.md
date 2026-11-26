# AGENTS.md — Pixel Blaster (macOS)

## Overview
Native macOS twin-stick pixel-art arena shooter written in Swift using AppKit, SpriteKit, GameController, CoreHaptics, and AVFoundation. Features 4 upgradeable weapons (Lv. 1–5), 3 suit upgrades in a between-wave Armory, procedural pixel-art sprites, real-time synthesized chiptune SFX, and full hardware controller + keyboard/mouse support.

## Tech Stack & Requirements
- **Language / Toolchain:** Swift 5.9+ (`swift-tools-version: 5.9`), Swift Package Manager (`Package.swift`)
- **Platform:** macOS 13.0+ (`.macOS(.v13)`)
- **Linked Apple Frameworks:** `AppKit`, `SpriteKit`, `GameController`, `CoreHaptics`, `AVFoundation`
- **Dependencies:** Zero third-party Swift packages; all sprites and audio are procedurally synthesized in code.

## Repository Structure
```text
pixel-blaster/
├── Package.swift                        # SwiftPM executable target `PixelBlaster` + framework link settings
├── README.md                            # Controls, arsenal, and build instructions
├── scripts/
│   └── package-app.sh                   # Builds release binary, generates Info.plist, ad-hoc signs .app, zips dist/
└── Sources/PixelBlaster/
    ├── main.swift                       # NSApplication + AppDelegate + GameView (SKView w/ mouse tracking, 60 FPS)
    ├── GameScene.swift                  # Core SKScene: wave spawning, HUD, pause/armory overlays, update loop
    ├── Entities.swift                   # Player, enemies, projectiles, scrap pickups, particles, physics state
    ├── WeaponSystem.swift               # 4 weapons (Pulse Pistol, Scatter Shotgun, Plasma SMG, Rail Cannon) Lv.1–5 + Suit upgrades
    ├── InputManager.swift               # Apple GameController (DualSense/Xbox/Switch Pro/MFi) + CoreHaptics + keyboard/mouse
    ├── PixelArt.swift                   # Procedural SKTexture pixel-art generator (nearest-neighbor filtering)
    └── AudioEngine.swift                # AVFoundation procedural chiptune SFX synthesizer + mute toggle (`M`)
```

## Architecture & Key Flows
- **App Bootstrap (`main.swift`):** Configures `NSApplication` with `.regular` activation policy, creates a resizable `NSWindow` (initial `1120x740`, min `900x600`), attaches `GameView` (`SKView` subclass overriding `updateTrackingAreas()` for mouse-aim tracking at `60` FPS), and presents `GameScene` with `.resizeFill`.
- **Simulation & Wave Loop (`GameScene.swift` + `Entities.swift` + `WeaponSystem.swift`):** Polls `InputManager` each frame for movement, twin-stick/mouse aim, fire, i-frame dash, and weapon switching (`1`–`4` / `Q`/`E` / shoulder buttons). Defeated enemies drop Scrap spent in the between-wave Armory on weapon levels (`Lv. 1`–`Lv. 5`) and suit upgrades (Armor, Thrusters, Scrap Magnet).
- **Controller & Haptics (`InputManager.swift`):** Uses `GCController` (`ExtendedGamepad`) for twin-stick play and Armory UI navigation, paired with `CoreHaptics` (`CHHapticEngine`) for controller rumble feedback.
- **Packaging (`scripts/package-app.sh`):** Runs `swift build -c release`, assembles `dist/PixelBlaster.app` with `GCSupportedGameControllers` / `GCSupportsControllerUserInteraction` in `Info.plist`, ad-hoc codesigns (`codesign --sign -`), and archives `dist/PixelBlaster-v<version>-macos-<arch>.zip` via `ditto`.

## Development & Commands
```bash
# Build and run in debug mode
swift run

# Release build
swift build -c release

# Package standalone ad-hoc signed .app bundle + zip (outputs to dist/)
./scripts/package-app.sh 1.0.0
```

## Configuration & Environment
- No `.env` files or runtime environment variables are used.
- `scripts/package-app.sh [version]` accepts an optional semver argument (defaults to `1.0.0`) and detects host architecture via `uname -m`.

## Conventions & Gotchas
- **No Xcode project or `.xcassets`:** Keep everything buildable via pure SwiftPM (`swift build` / `swift run`); generate textures procedurally in `PixelArt.swift` with `.nearest` texture filtering to preserve crisp pixels.
- **Controller `Info.plist` keys:** `GCSupportedGameControllers` (`ExtendedGamepad`) and `GCSupportsControllerUserInteraction` in `scripts/package-app.sh` are required for full macOS GameController support in the packaged `.app`.
- **Ad-hoc signing & Gatekeeper:** `package-app.sh` uses `--sign -`; packaged builds require right-click → Open on first launch unless signed with a Developer ID.
- **No automated test target yet:** There is currently no `Tests/` target in `Package.swift`; verify changes with `swift build` and manual playtesting via `swift run`.
