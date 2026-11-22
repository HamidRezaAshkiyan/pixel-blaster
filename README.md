# Pixel Blaster (macOS)

A native macOS twin-stick pixel-art shooter with upgradeable guns, retro synthesized chiptune SFX, and full **Apple GameController + CoreHaptics** support (DualSense, DualShock 4, Xbox Wireless, Switch Pro, and MFi controllers), plus full keyboard & mouse support.

## Download

Grab the latest pre-built `PixelBlaster.app` from the [Releases](https://github.com/HamidRezaAshkiyan/pixel-blaster/releases) page:

1. Download `PixelBlaster-v1.0.0-macos-arm64.zip` and unzip it.
2. Open `PixelBlaster.app` (on first launch, right-click → **Open** if macOS Gatekeeper asks, since the app is ad-hoc signed).

## Build from Source

Requires macOS 13+ and Swift 5.9+:

```bash
swift run
```

To package a standalone `.app` bundle:

```bash
./scripts/package-app.sh 1.0.0
```

## Controls

| Action | Game Controller | Keyboard + Mouse |
| --- | --- | --- |
| Move | Left Stick / D-Pad | `WASD` / Arrow Keys |
| Aim | Right Stick | Mouse |
| Shoot | `RT` / `R2` or `RB` / `R1` | Left Click |
| Dash (i-frames) | `LT` / `L2` or `A` / `Cross` | `Space` / `Shift` |
| Switch Weapon | `LB` / `L1` / `X` / `Y` | `1`–`4` or `Q` / `E` |
| Armory Navigate | Left Stick / D-Pad | Arrow Keys / `WASD` / Mouse |
| Buy / Confirm | `A` / `Cross` | `Enter` / Click |
| Start Next Wave | `B` / `Circle` | `Esc` / Click |
| Pause | `Options` / `Menu` | `Esc` |
| Mute Audio | — | `M` |

## Arsenal & Upgrades

Collect **Scrap** from defeated enemies and spend it in the between-wave **Armory** to unlock and upgrade guns from **Lv. 1 to Lv. 5**:

- **Pulse Pistol** — Balanced starter sidearm; upgrades into Twin Bolts, Piercing Bolts, and Triple Plasma Spread.
- **Scatter Shotgun** — Close-range pellet blast with heavy knockback; upgrades up to 11 piercing pellets.
- **Plasma SMG** — High-ROF plasma stream; upgrades into a Dual-Barrel Piercing Overclocked SMG.
- **Rail Cannon** — Hyper-velocity piercing slug; upgrades into Twin Rail Beams piercing up to 11 enemies.
- **Suit Upgrades** — Armor (+Max HP & Heal), Thrusters (+Speed & faster Dash), and Scrap Magnet (+Pickup range & bonus Scrap).
