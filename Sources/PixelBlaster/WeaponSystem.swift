import AppKit
import SpriteKit

enum WeaponType: Int, CaseIterable {
    case pistol = 0
    case shotgun = 1
    case smg = 2
    case railgun = 3

    var name: String {
        switch self {
        case .pistol: return "PULSE PISTOL"
        case .shotgun: return "SCATTER SHOTGUN"
        case .smg: return "PLASMA SMG"
        case .railgun: return "RAIL CANNON"
        }
    }

    var shortName: String {
        switch self {
        case .pistol: return "PISTOL"
        case .shotgun: return "SHOTGUN"
        case .smg: return "SMG"
        case .railgun: return "RAILGUN"
        }
    }

    var unlockCost: Int {
        switch self {
        case .pistol: return 0
        case .shotgun: return 45
        case .smg: return 75
        case .railgun: return 120
        }
    }

    var gunTexture: SKTexture {
        switch self {
        case .pistol: return PixelArt.gunPistol
        case .shotgun: return PixelArt.gunShotgun
        case .smg: return PixelArt.gunSMG
        case .railgun: return PixelArt.gunRailgun
        }
    }

    var soundEffect: SoundEffect {
        switch self {
        case .pistol: return .pistolShot
        case .shotgun: return .shotgunShot
        case .smg: return .smgShot
        case .railgun: return .railgunShot
        }
    }

    var accentColor: NSColor {
        switch self {
        case .pistol: return NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1)
        case .shotgun: return NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        case .smg: return NSColor(red: 0.75, green: 0.52, blue: 0.99, alpha: 1)
        case .railgun: return NSColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1)
        }
    }
}

struct WeaponStats {
    let damage: CGFloat
    let fireCooldown: TimeInterval
    let projectileSpeed: CGFloat
    let projectileCount: Int
    let spreadRadians: CGFloat
    let pierceCount: Int
    let knockback: CGFloat
    let bulletCoreHex: UInt32
    let bulletGlowHex: UInt32
    let wideBullet: Bool
    let screenShake: CGFloat
    let hapticIntensity: Float
    let upgradeSummary: String
}

final class WeaponLoadout {
    static let maxLevel = 5

    private(set) var unlocked: Set<WeaponType> = [.pistol]
    private(set) var levels: [WeaponType: Int] = [
        .pistol: 1,
        .shotgun: 1,
        .smg: 1,
        .railgun: 1
    ]
    private(set) var currentWeapon: WeaponType = .pistol

    // Suit upgrades
    private(set) var armorLevel: Int = 1
    private(set) var speedLevel: Int = 1
    private(set) var magnetLevel: Int = 1

    func reset() {
        unlocked = [.pistol]
        levels = [.pistol: 1, .shotgun: 1, .smg: 1, .railgun: 1]
        currentWeapon = .pistol
        armorLevel = 1
        speedLevel = 1
        magnetLevel = 1
    }

    func level(of type: WeaponType) -> Int {
        levels[type] ?? 1
    }

    func isUnlocked(_ type: WeaponType) -> Bool {
        unlocked.contains(type)
    }

    func upgradeCost(for type: WeaponType) -> Int {
        if !isUnlocked(type) {
            return type.unlockCost
        }
        let lv = level(of: type)
        switch type {
        case .pistol: return 30 + (lv - 1) * 28
        case .shotgun: return 45 + (lv - 1) * 35
        case .smg: return 55 + (lv - 1) * 40
        case .railgun: return 75 + (lv - 1) * 50
        }
    }

    func canUpgrade(_ type: WeaponType) -> Bool {
        !isUnlocked(type) || level(of: type) < WeaponLoadout.maxLevel
    }

    @discardableResult
    func buyOrUpgrade(_ type: WeaponType) -> Bool {
        if !isUnlocked(type) {
            unlocked.insert(type)
            currentWeapon = type
            return true
        }
        let lv = level(of: type)
        guard lv < WeaponLoadout.maxLevel else { return false }
        levels[type] = lv + 1
        return true
    }

    @discardableResult
    func select(_ type: WeaponType) -> Bool {
        guard isUnlocked(type) else { return false }
        currentWeapon = type
        return true
    }

    func cycleWeapon(step: Int) {
        let available = WeaponType.allCases.filter { unlocked.contains($0) }
        guard available.count > 1, let idx = available.firstIndex(of: currentWeapon) else { return }
        let next = (idx + step + available.count) % available.count
        currentWeapon = available[next]
    }

    func armorUpgradeCost() -> Int { 35 + (armorLevel - 1) * 25 }
    func speedUpgradeCost() -> Int { 35 + (speedLevel - 1) * 30 }
    func magnetUpgradeCost() -> Int { 30 + (magnetLevel - 1) * 25 }

    func upgradeArmor() { armorLevel += 1 }
    func upgradeSpeed() { speedLevel += 1 }
    func upgradeMagnet() { magnetLevel += 1 }

    var currentStats: WeaponStats {
        stats(for: currentWeapon, level: level(of: currentWeapon))
    }

    func nextUpgradeDescription(for type: WeaponType) -> String {
        if !isUnlocked(type) {
            switch type {
            case .pistol: return "Starter sidearm"
            case .shotgun: return "5-pellet close-range blast"
            case .smg: return "High-ROF plasma stream"
            case .railgun: return "Piercing hyper-velocity slug"
            }
        }
        let lv = level(of: type)
        if lv >= WeaponLoadout.maxLevel { return "MAX LEVEL" }
        return stats(for: type, level: lv + 1).upgradeSummary
    }

    func stats(for type: WeaponType, level: Int) -> WeaponStats {
        let lv = max(1, min(WeaponLoadout.maxLevel, level))
        switch type {
        case .pistol:
            let count = lv >= 5 ? 3 : (lv >= 3 ? 2 : 1)
            let pierce = lv >= 4 ? 1 : 0
            let summary: String = {
                switch lv {
                case 2: return "+30% DMG & Faster Fire"
                case 3: return "Twin Bolts + Higher DMG"
                case 4: return "Piercing Bolts + Rapid Fire"
                case 5: return "Triple Plasma Spread!"
                default: return "Balanced sidearm"
                }
            }()
            return WeaponStats(
                damage: 22 + CGFloat(lv - 1) * 7,
                fireCooldown: max(0.11, 0.24 - Double(lv - 1) * 0.03),
                projectileSpeed: 680 + CGFloat(lv - 1) * 40,
                projectileCount: count,
                spreadRadians: count == 1 ? 0.03 : 0.14,
                pierceCount: pierce,
                knockback: 90,
                bulletCoreHex: lv >= 4 ? 0x38BDF8 : 0x60A5FA,
                bulletGlowHex: lv >= 4 ? 0x0284C7 : 0x2563EB,
                wideBullet: false,
                screenShake: 2.2,
                hapticIntensity: 0.28,
                upgradeSummary: summary
            )

        case .shotgun:
            let pellets = [5, 6, 7, 9, 11][lv - 1]
            let pierce = lv >= 5 ? 1 : 0
            let summary: String = {
                switch lv {
                case 2: return "6 Pellets + Heavy Punch"
                case 3: return "7 Pellets + Faster Pump"
                case 4: return "9 Pellets + High DMG"
                case 5: return "11 Piercing Dragon Pellets!"
                default: return "5-pellet scatter"
                }
            }()
            return WeaponStats(
                damage: 14 + CGFloat(lv - 1) * 4,
                fireCooldown: max(0.36, 0.62 - Double(lv - 1) * 0.06),
                projectileSpeed: 600 + CGFloat(lv - 1) * 35,
                projectileCount: pellets,
                spreadRadians: 0.48,
                pierceCount: pierce,
                knockback: 185,
                bulletCoreHex: 0xFACC15,
                bulletGlowHex: 0xEA580C,
                wideBullet: false,
                screenShake: 6.5,
                hapticIntensity: 0.72,
                upgradeSummary: summary
            )

        case .smg:
            let count = lv >= 4 ? 2 : 1
            let pierce = lv >= 5 ? 1 : 0
            let summary: String = {
                switch lv {
                case 2: return "+25% Fire Rate & DMG"
                case 3: return "Hyper ROF Plasma Bolts"
                case 4: return "Dual-Barrel Plasma Stream!"
                case 5: return "Piercing Overclocked SMG!"
                default: return "Rapid plasma fire"
                }
            }()
            return WeaponStats(
                damage: 11 + CGFloat(lv - 1) * 3.5,
                fireCooldown: max(0.055, 0.098 - Double(lv - 1) * 0.01),
                projectileSpeed: 740 + CGFloat(lv - 1) * 35,
                projectileCount: count,
                spreadRadians: count == 1 ? 0.12 : 0.18,
                pierceCount: pierce,
                knockback: 45,
                bulletCoreHex: 0xE879F9,
                bulletGlowHex: 0x9333EA,
                wideBullet: false,
                screenShake: 1.5,
                hapticIntensity: 0.22,
                upgradeSummary: summary
            )

        case .railgun:
            let count = lv >= 5 ? 2 : 1
            let pierce = 3 + (lv - 1) * 2
            let summary: String = {
                switch lv {
                case 2: return "Pierce 5 + Faster Charge"
                case 3: return "Pierce 7 + Huge DMG"
                case 4: return "Pierce 9 + Hyper Velocity"
                case 5: return "Twin Rail Beams (Pierce 11)!"
                default: return "Piercing rail slug"
                }
            }()
            return WeaponStats(
                damage: 72 + CGFloat(lv - 1) * 28,
                fireCooldown: max(0.45, 0.85 - Double(lv - 1) * 0.095),
                projectileSpeed: 1120 + CGFloat(lv - 1) * 80,
                projectileCount: count,
                spreadRadians: count == 1 ? 0.0 : 0.08,
                pierceCount: pierce,
                knockback: 220,
                bulletCoreHex: 0x67E8F9,
                bulletGlowHex: 0x06B6D4,
                wideBullet: true,
                screenShake: 8.5,
                hapticIntensity: 0.90,
                upgradeSummary: summary
            )
        }
    }
}
