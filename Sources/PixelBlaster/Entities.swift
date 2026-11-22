import AppKit
import SpriteKit

enum EnemyKind {
    case swarmer
    case drone
    case brute
    case boss
}

final class EnemyEntity {
    let id = UUID()
    let kind: EnemyKind
    let node: SKSpriteNode
    let hpBarBg: SKShapeNode?
    let hpBarFill: SKShapeNode?

    var hp: CGFloat
    let maxHP: CGFloat
    let speed: CGFloat
    let radius: CGFloat
    let contactDamage: CGFloat
    let scrapValue: Int
    let scoreValue: Int

    var knockbackVel: CGVector = .zero
    var shootCooldown: TimeInterval
    var phaseTimer: TimeInterval = 0
    var hitFlashTimer: TimeInterval = 0

    init(kind: EnemyKind, position: CGPoint, wave: Int) {
        self.kind = kind
        let waveScale = 1.0 + CGFloat(max(0, wave - 1)) * 0.16

        switch kind {
        case .swarmer:
            self.node = SKSpriteNode(texture: PixelArt.enemySwarmer)
            self.maxHP = 32 * waveScale
            self.speed = min(230, 128 + CGFloat(wave) * 6)
            self.radius = 16
            self.contactDamage = 12
            self.scrapValue = 5
            self.scoreValue = 100
            self.shootCooldown = 999

        case .drone:
            self.node = SKSpriteNode(texture: PixelArt.enemyDrone)
            self.maxHP = 48 * waveScale
            self.speed = min(155, 92 + CGFloat(wave) * 4)
            self.radius = 17
            self.contactDamage = 14
            self.scrapValue = 8
            self.scoreValue = 180
            self.shootCooldown = Double.random(in: 1.0...2.0)

        case .brute:
            self.node = SKSpriteNode(texture: PixelArt.enemyBrute)
            self.maxHP = 135 * waveScale
            self.speed = min(125, 72 + CGFloat(wave) * 3)
            self.radius = 24
            self.contactDamage = 22
            self.scrapValue = 16
            self.scoreValue = 350
            self.shootCooldown = Double.random(in: 1.8...2.8)

        case .boss:
            self.node = SKSpriteNode(texture: PixelArt.enemyBoss)
            self.maxHP = 720 * waveScale
            self.speed = 86 + CGFloat(wave) * 2
            self.radius = 40
            self.contactDamage = 28
            self.scrapValue = 65
            self.scoreValue = 1500
            self.shootCooldown = 1.2
        }

        self.hp = self.maxHP
        self.node.position = position
        self.node.zPosition = kind == .boss ? 12 : 10

        if kind == .brute || kind == .boss {
            let barW: CGFloat = kind == .boss ? 86 : 42
            let barH: CGFloat = kind == .boss ? 8 : 5
            let yOff: CGFloat = (self.node.size.height * 0.5) + 10

            let bg = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
            bg.fillColor = NSColor(white: 0.08, alpha: 0.85)
            bg.strokeColor = NSColor(white: 0.35, alpha: 0.9)
            bg.lineWidth = 1
            bg.position = CGPoint(x: 0, y: yOff)
            bg.zPosition = 20
            self.node.addChild(bg)

            let fill = SKShapeNode(rect: CGRect(x: -barW / 2, y: -barH / 2, width: barW, height: barH), cornerRadius: 1)
            fill.fillColor = kind == .boss
                ? NSColor(red: 0.96, green: 0.25, blue: 0.37, alpha: 1)
                : NSColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
            fill.strokeColor = .clear
            bg.addChild(fill)

            self.hpBarBg = bg
            self.hpBarFill = fill
        } else {
            self.hpBarBg = nil
            self.hpBarFill = nil
        }
    }

    func updateHealthBar() {
        guard let fill = hpBarFill else { return }
        let ratio = max(0, min(1, hp / maxHP))
        fill.xScale = ratio
    }
}

final class ProjectileEntity {
    let node: SKSpriteNode
    let velocity: CGVector
    let damage: CGFloat
    let isPlayer: Bool
    let radius: CGFloat
    let knockback: CGFloat
    var remainingPierce: Int
    var hitEnemyIDs: Set<UUID> = []
    var lifetime: TimeInterval

    init(
        texture: SKTexture,
        position: CGPoint,
        angle: CGFloat,
        speed: CGFloat,
        damage: CGFloat,
        isPlayer: Bool,
        radius: CGFloat,
        pierce: Int,
        knockback: CGFloat,
        lifetime: TimeInterval = 2.0
    ) {
        self.node = SKSpriteNode(texture: texture)
        self.node.position = position
        self.node.zRotation = angle
        self.node.zPosition = isPlayer ? 15 : 14
        self.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        self.damage = damage
        self.isPlayer = isPlayer
        self.radius = radius
        self.knockback = knockback
        self.remainingPierce = pierce
        self.lifetime = lifetime
    }
}

enum PickupKind {
    case scrap(Int)
    case medkit(CGFloat)
}

final class PickupEntity {
    let node: SKSpriteNode
    let kind: PickupKind
    var lifetime: TimeInterval = 18.0
    var bobPhase: CGFloat = CGFloat.random(in: 0...(2 * .pi))

    init(kind: PickupKind, position: CGPoint) {
        self.kind = kind
        switch kind {
        case .scrap:
            self.node = SKSpriteNode(texture: PixelArt.scrapCoin)
        case .medkit:
            self.node = SKSpriteNode(texture: PixelArt.medkit)
        }
        self.node.position = position
        self.node.zPosition = 8
    }
}
