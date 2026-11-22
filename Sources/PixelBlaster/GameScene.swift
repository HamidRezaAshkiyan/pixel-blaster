import AppKit
import SpriteKit

enum GameState {
    case title
    case playing
    case armory
    case paused
    case gameOver
}

enum ShopItem {
    case weapon(WeaponType)
    case armor
    case speed
    case magnet
    case nextWave
}

final class GameScene: SKScene {
    private let input = InputManager()
    private let loadout = WeaponLoadout()

    private var state: GameState = .title
    private var lastUpdateTime: TimeInterval = 0

    // Arena dimensions
    private let arenaSize = CGSize(width: 1440, height: 960)
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private let overlayNode = SKNode()

    // Player nodes & state
    private let playerNode = SKSpriteNode(texture: PixelArt.playerFrames[0])
    private let gunNode = SKSpriteNode(texture: PixelArt.gunPistol)
    private let reticleNode = SKSpriteNode(texture: PixelArt.reticle)
    private var playerHP: CGFloat = 100
    private var playerMaxHP: CGFloat = 100
    private var playerAimAngle: CGFloat = 0
    private var fireCooldown: TimeInterval = 0
    private var invulnTimer: TimeInterval = 0
    private var dashTimer: TimeInterval = 0
    private var dashCooldown: TimeInterval = 0
    private var dashVector: CGVector = .zero
    private var animTimer: TimeInterval = 0
    private var animFrame: Int = 0

    // Wave & progression state
    private var wave: Int = 1
    private var scrap: Int = 0
    private var score: Int = 0
    private var highScore: Int = UserDefaults.standard.integer(forKey: "PixelBlasterHighScore")
    private var kills: Int = 0
    private var enemiesRemainingToSpawn: [EnemyKind] = []
    private var spawnTimer: TimeInterval = 0
    private var waveClearDelay: TimeInterval = 0

    // Entities
    private var enemies: [EnemyEntity] = []
    private var projectiles: [ProjectileEntity] = []
    private var pickups: [PickupEntity] = []

    // Screen shake
    private var shakeIntensity: CGFloat = 0

    // Cached bullet textures
    private var bulletTextures: [String: SKTexture] = [:]
    private let enemyBulletTexture = PixelArt.bulletTexture(core: 0xFB7185, glow: 0xE11D48, wide: false)

    // HUD elements
    private var hpBarFill: SKShapeNode!
    private var hpLabel: SKLabelNode!
    private var dashBarFill: SKShapeNode!
    private var waveLabel: SKLabelNode!
    private var scrapLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var controllerBadge: SKLabelNode!
    private var weaponSlotNodes: [(bg: SKShapeNode, label: SKLabelNode, lvl: SKLabelNode)] = []
    private var toastLabel: SKLabelNode!

    // Shop / Armory UI
    private let shopItems: [ShopItem] = [
        .weapon(.pistol), .weapon(.shotgun), .weapon(.smg), .weapon(.railgun),
        .armor, .speed, .magnet, .nextWave
    ]
    private var selectedShopIndex: Int = 0
    private var shopCardFrames: [(index: Int, frame: CGRect)] = []

    override func didMove(to view: SKView) {
        backgroundColor = NSColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1)

        addChild(worldNode)
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.addChild(hudNode)
        cameraNode.addChild(overlayNode)

        buildArena()
        buildPlayer()
        buildHUD()

        input.onControllerStatusChanged = { [weak self] name in
            guard let self = self else { return }
            self.updateControllerBadge()
            if let name = name {
                self.showToast("CONTROLLER CONNECTED: \(name.uppercased())", color: NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1))
                self.input.playHaptic(intensity: 0.5, sharpness: 0.6, duration: 0.12)
            } else {
                self.showToast("CONTROLLER DISCONNECTED — KEYBOARD & MOUSE ACTIVE", color: NSColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1))
            }
            if self.state == .title {
                self.showTitleOverlay()
            }
        }

        updateControllerBadge()
        showTitleOverlay()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
        refreshCurrentOverlay()
    }

    // MARK: - Scene Construction

    private func buildArena() {
        let tileTex = PixelArt.floorTile
        let tileW = tileTex.size().width
        let tileH = tileTex.size().height
        let cols = Int(ceil(arenaSize.width / tileW))
        let rows = Int(ceil(arenaSize.height / tileH))

        let startX = -arenaSize.width / 2
        let startY = -arenaSize.height / 2

        for r in 0..<rows {
            for c in 0..<cols {
                let tile = SKSpriteNode(texture: tileTex)
                tile.anchorPoint = CGPoint(x: 0, y: 0)
                tile.position = CGPoint(x: startX + CGFloat(c) * tileW, y: startY + CGFloat(r) * tileH)
                tile.zPosition = -10
                worldNode.addChild(tile)
            }
        }

        // Neon arena border walls
        let border = SKShapeNode(rect: CGRect(x: -arenaSize.width / 2, y: -arenaSize.height / 2, width: arenaSize.width, height: arenaSize.height))
        border.strokeColor = NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 0.85)
        border.lineWidth = 6
        border.glowWidth = 4
        border.fillColor = .clear
        border.zPosition = -2
        worldNode.addChild(border)
    }

    private func buildPlayer() {
        playerNode.zPosition = 11
        worldNode.addChild(playerNode)

        gunNode.anchorPoint = CGPoint(x: 0.2, y: 0.5)
        gunNode.zPosition = 13
        worldNode.addChild(gunNode)

        reticleNode.zPosition = 30
        worldNode.addChild(reticleNode)
    }

    private func buildHUD() {
        hudNode.zPosition = 100

        // HP bar
        let hpBg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 210, height: 18), cornerRadius: 3)
        hpBg.fillColor = NSColor(white: 0.08, alpha: 0.85)
        hpBg.strokeColor = NSColor(red: 0.35, green: 0.45, blue: 0.6, alpha: 0.9)
        hpBg.lineWidth = 2
        hpBg.name = "hpBg"
        hudNode.addChild(hpBg)

        hpBarFill = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 206, height: 14), cornerRadius: 2)
        hpBarFill.fillColor = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 2, y: 2)
        hpBg.addChild(hpBarFill)

        hpLabel = makeLabel("HP 100/100", size: 12, color: .white)
        hpLabel.horizontalAlignmentMode = .center
        hpLabel.verticalAlignmentMode = .center
        hpLabel.position = CGPoint(x: 105, y: 9)
        hpBg.addChild(hpLabel)

        // Dash bar
        let dashBg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 130, height: 8), cornerRadius: 2)
        dashBg.fillColor = NSColor(white: 0.08, alpha: 0.85)
        dashBg.strokeColor = NSColor(white: 0.3, alpha: 0.8)
        dashBg.lineWidth = 1
        dashBg.name = "dashBg"
        hudNode.addChild(dashBg)

        dashBarFill = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 128, height: 6), cornerRadius: 1)
        dashBarFill.fillColor = NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1)
        dashBarFill.strokeColor = .clear
        dashBarFill.position = CGPoint(x: 1, y: 1)
        dashBg.addChild(dashBarFill)

        let dashText = makeLabel("DASH", size: 10, color: NSColor(red: 0.58, green: 0.82, blue: 0.98, alpha: 1))
        dashText.horizontalAlignmentMode = .left
        dashText.position = CGPoint(x: 138, y: 0)
        dashBg.addChild(dashText)

        // Top Center: Wave
        waveLabel = makeLabel("WAVE 1", size: 22, color: .white)
        waveLabel.horizontalAlignmentMode = .center
        hudNode.addChild(waveLabel)

        // Top Right: Scrap & Score & Controller badge
        scrapLabel = makeLabel("SCRAP: 0", size: 16, color: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1))
        scrapLabel.horizontalAlignmentMode = .right
        hudNode.addChild(scrapLabel)

        scoreLabel = makeLabel("SCORE: 0", size: 14, color: NSColor(white: 0.85, alpha: 1))
        scoreLabel.horizontalAlignmentMode = .right
        hudNode.addChild(scoreLabel)

        controllerBadge = makeLabel("KEYBOARD + MOUSE", size: 11, color: NSColor(white: 0.65, alpha: 1))
        controllerBadge.horizontalAlignmentMode = .right
        hudNode.addChild(controllerBadge)

        // Bottom Weapon Slots
        weaponSlotNodes.removeAll()
        for (idx, wep) in WeaponType.allCases.enumerated() {
            let bg = SKShapeNode(rectOf: CGSize(width: 112, height: 42), cornerRadius: 5)
            bg.fillColor = NSColor(red: 0.07, green: 0.10, blue: 0.17, alpha: 0.88)
            bg.strokeColor = NSColor(white: 0.28, alpha: 0.9)
            bg.lineWidth = 2
            hudNode.addChild(bg)

            let nameLbl = makeLabel("\(idx + 1). \(wep.shortName)", size: 11, color: .white)
            nameLbl.position = CGPoint(x: 0, y: 5)
            bg.addChild(nameLbl)

            let lvlLbl = makeLabel("LOCKED", size: 10, color: NSColor(white: 0.55, alpha: 1))
            lvlLbl.position = CGPoint(x: 0, y: -12)
            bg.addChild(lvlLbl)

            weaponSlotNodes.append((bg, nameLbl, lvlLbl))
        }

        // Toast banner
        toastLabel = makeLabel("", size: 14, color: .white)
        toastLabel.horizontalAlignmentMode = .center
        toastLabel.alpha = 0
        toastLabel.zPosition = 200
        hudNode.addChild(toastLabel)

        layoutHUD()
    }

    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }
        let hw = size.width / 2
        let hh = size.height / 2

        if let hpBg = hudNode.childNode(withName: "hpBg") {
            hpBg.position = CGPoint(x: -hw + 20, y: hh - 38)
        }
        if let dashBg = hudNode.childNode(withName: "dashBg") {
            dashBg.position = CGPoint(x: -hw + 20, y: hh - 54)
        }

        waveLabel?.position = CGPoint(x: 0, y: hh - 38)
        scrapLabel?.position = CGPoint(x: hw - 20, y: hh - 34)
        scoreLabel?.position = CGPoint(x: hw - 20, y: hh - 54)
        controllerBadge?.position = CGPoint(x: hw - 20, y: -hh + 18)

        let slotSpacing: CGFloat = 122
        let totalW = slotSpacing * CGFloat(weaponSlotNodes.count - 1)
        for (i, slot) in weaponSlotNodes.enumerated() {
            slot.bg.position = CGPoint(x: -totalW / 2 + CGFloat(i) * slotSpacing, y: -hh + 34)
        }

        toastLabel?.position = CGPoint(x: 0, y: hh - 82)
    }

    private func updateHUD() {
        let hpRatio = max(0, min(1, playerHP / playerMaxHP))
        hpBarFill.xScale = hpRatio
        hpBarFill.fillColor = hpRatio > 0.45
            ? NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
            : (hpRatio > 0.2 ? NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1) : NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
        hpLabel.text = "HP \(Int(ceil(playerHP)))/\(Int(playerMaxHP))"

        let maxDashCD = max(0.45, 1.05 - Double(loadout.speedLevel - 1) * 0.12)
        let dashRatio = max(0, min(1, 1.0 - (dashCooldown / maxDashCD)))
        dashBarFill.xScale = CGFloat(dashRatio)

        let isBossWave = wave % 5 == 0
        waveLabel.text = isBossWave ? "WAVE \(wave) — BOSS!" : "WAVE \(wave)"
        waveLabel.fontColor = isBossWave ? NSColor(red: 0.98, green: 0.44, blue: 0.52, alpha: 1) : .white
        scrapLabel.text = "SCRAP: \(scrap)"
        scoreLabel.text = "SCORE: \(score)"

        for (i, wep) in WeaponType.allCases.enumerated() {
            let slot = weaponSlotNodes[i]
            let unlocked = loadout.isUnlocked(wep)
            let isSelected = loadout.currentWeapon == wep
            slot.bg.strokeColor = isSelected ? wep.accentColor : NSColor(white: unlocked ? 0.38 : 0.2, alpha: 0.85)
            slot.bg.lineWidth = isSelected ? 3 : 1.5
            slot.bg.alpha = unlocked ? 1.0 : 0.45
            slot.label.fontColor = isSelected ? wep.accentColor : .white
            if unlocked {
                let lv = loadout.level(of: wep)
                slot.lvl.text = lv >= WeaponLoadout.maxLevel ? "MAX" : "LV.\(lv)"
                slot.lvl.fontColor = lv >= WeaponLoadout.maxLevel
                    ? NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1)
                    : NSColor(white: 0.78, alpha: 1)
            } else {
                slot.lvl.text = "LOCKED"
                slot.lvl.fontColor = NSColor(white: 0.45, alpha: 1)
            }
        }
    }

    private func updateControllerBadge() {
        if let name = input.controllerName {
            controllerBadge.text = "GAMEPAD: \(name.uppercased())"
            controllerBadge.fontColor = NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1)
        } else {
            controllerBadge.text = "KEYBOARD + MOUSE (CONNECT CONTROLLER ANYTIME)"
            controllerBadge.fontColor = NSColor(white: 0.60, alpha: 1)
        }
    }

    private func showToast(_ text: String, color: NSColor = .white) {
        toastLabel.removeAllActions()
        toastLabel.text = text
        toastLabel.fontColor = color
        toastLabel.alpha = 1.0
        toastLabel.run(.sequence([
            .wait(forDuration: 2.2),
            .fadeOut(withDuration: 0.5)
        ]))
    }

    // MARK: - Game Lifecycle

    private func startNewGame() {
        clearEntities()
        loadout.reset()

        playerMaxHP = 100
        playerHP = 100
        playerNode.position = .zero
        playerNode.alpha = 1.0
        gunNode.texture = loadout.currentWeapon.gunTexture
        invulnTimer = 0
        dashTimer = 0
        dashCooldown = 0
        fireCooldown = 0

        wave = 1
        scrap = 0
        score = 0
        kills = 0

        overlayNode.removeAllChildren()
        hudNode.isHidden = false
        reticleNode.isHidden = false
        state = .playing

        beginWave(wave)
        updateHUD()
    }

    private func clearEntities() {
        enemies.forEach { $0.node.removeFromParent() }
        enemies.removeAll()
        projectiles.forEach { $0.node.removeFromParent() }
        projectiles.removeAll()
        pickups.forEach { $0.node.removeFromParent() }
        pickups.removeAll()
    }

    private func beginWave(_ waveNum: Int) {
        wave = waveNum
        enemiesRemainingToSpawn.removeAll()
        waveClearDelay = 0
        spawnTimer = 0.4

        let totalEnemies = 7 + waveNum * 3
        for i in 0..<totalEnemies {
            if waveNum >= 3 && i % 6 == 0 {
                enemiesRemainingToSpawn.append(.brute)
            } else if waveNum >= 2 && i % 3 == 0 {
                enemiesRemainingToSpawn.append(.drone)
            } else {
                enemiesRemainingToSpawn.append(.swarmer)
            }
        }

        if waveNum % 5 == 0 {
            enemiesRemainingToSpawn.append(.boss)
            showToast("WARNING: BOSS DETECTED — WAVE \(waveNum)!", color: NSColor(red: 0.98, green: 0.25, blue: 0.37, alpha: 1))
        } else {
            showToast("WAVE \(waveNum) INCOMING!", color: NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1))
        }

        enemiesRemainingToSpawn.shuffle()
        AudioEngine.shared.play(.waveStart)
        updateHUD()
    }

    // MARK: - Main Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(0.05, max(0.001, currentTime - lastUpdateTime))
        lastUpdateTime = currentTime

        input.pollController(dt: dt)

        if input.mutePressed {
            AudioEngine.shared.isMuted.toggle()
            showToast(AudioEngine.shared.isMuted ? "AUDIO MUTED" : "AUDIO ON", color: .white)
        }

        switch state {
        case .title:
            if input.confirmPressed {
                AudioEngine.shared.play(.uiConfirm)
                startNewGame()
            }

        case .playing:
            if input.pausePressed {
                state = .paused
                showPauseOverlay()
            } else {
                updatePlaying(dt: dt)
            }

        case .armory:
            updateArmoryNavigation()

        case .paused:
            if input.pausePressed || input.confirmPressed {
                AudioEngine.shared.play(.uiConfirm)
                overlayNode.removeAllChildren()
                state = .playing
            } else if input.cancelPressed {
                AudioEngine.shared.play(.uiMove)
                showTitleOverlay()
            }

        case .gameOver:
            if input.confirmPressed {
                AudioEngine.shared.play(.uiConfirm)
                startNewGame()
            } else if input.cancelPressed {
                AudioEngine.shared.play(.uiMove)
                showTitleOverlay()
            }
        }

        input.endFrame()
    }

    private func updatePlaying(dt: TimeInterval) {
        // Weapon switching
        if let slot = input.directWeaponSlot, let wep = WeaponType(rawValue: slot) {
            if loadout.select(wep) {
                gunNode.texture = wep.gunTexture
                AudioEngine.shared.play(.uiMove)
                updateHUD()
            }
        } else if input.nextWeaponPressed {
            loadout.cycleWeapon(step: 1)
            gunNode.texture = loadout.currentWeapon.gunTexture
            AudioEngine.shared.play(.uiMove)
            updateHUD()
        } else if input.prevWeaponPressed {
            loadout.cycleWeapon(step: -1)
            gunNode.texture = loadout.currentWeapon.gunTexture
            AudioEngine.shared.play(.uiMove)
            updateHUD()
        }

        // Player movement & dash
        let moveSpeed: CGFloat = 250 + CGFloat(loadout.speedLevel - 1) * 30
        let maxDashCD = max(0.45, 1.05 - Double(loadout.speedLevel - 1) * 0.12)
        if dashCooldown > 0 { dashCooldown = max(0, dashCooldown - dt) }
        if invulnTimer > 0 {
            invulnTimer = max(0, invulnTimer - dt)
            playerNode.alpha = (Int(invulnTimer * 24) % 2 == 0) ? 0.45 : 1.0
        } else {
            playerNode.alpha = 1.0
        }

        let moveInput = input.moveVector
        if input.dashPressed && dashCooldown <= 0 && dashTimer <= 0 {
            dashTimer = 0.16
            dashCooldown = maxDashCD
            invulnTimer = max(invulnTimer, 0.22)
            let dir = hypot(moveInput.dx, moveInput.dy) > 0.1
                ? moveInput
                : CGVector(dx: cos(playerAimAngle), dy: sin(playerAimAngle))
            let len = max(0.001, hypot(dir.dx, dir.dy))
            dashVector = CGVector(dx: (dir.dx / len) * 680, dy: (dir.dy / len) * 680)
            AudioEngine.shared.play(.dash)
            input.playHaptic(intensity: 0.45, sharpness: 0.7, duration: 0.08)
        }

        var vx: CGFloat = 0
        var vy: CGFloat = 0
        if dashTimer > 0 {
            dashTimer -= dt
            vx = dashVector.dx
            vy = dashVector.dy
            spawnDashGhost()
        } else {
            vx = moveInput.dx * moveSpeed
            vy = moveInput.dy * moveSpeed
        }

        let halfW = arenaSize.width / 2 - 24
        let halfH = arenaSize.height / 2 - 24
        playerNode.position.x = max(-halfW, min(halfW, playerNode.position.x + vx * CGFloat(dt)))
        playerNode.position.y = max(-halfH, min(halfH, playerNode.position.y + vy * CGFloat(dt)))

        // Animate player legs while moving
        if hypot(vx, vy) > 20 {
            animTimer += dt
            if animTimer >= 0.12 {
                animTimer = 0
                animFrame = (animFrame + 1) % PixelArt.playerFrames.count
                playerNode.texture = PixelArt.playerFrames[animFrame]
            }
        } else {
            playerNode.texture = PixelArt.playerFrames[0]
        }

        // Aiming
        if input.aimMode == .controller {
            playerAimAngle = input.controllerAimAngle
            reticleNode.position = CGPoint(
                x: playerNode.position.x + cos(playerAimAngle) * 145,
                y: playerNode.position.y + sin(playerAimAngle) * 145
            )
        } else {
            let worldMouse = convert(input.mouseScenePosition, to: worldNode)
            let dx = worldMouse.x - playerNode.position.x
            let dy = worldMouse.y - playerNode.position.y
            playerAimAngle = atan2(dy, dx)
            reticleNode.position = worldMouse
        }

        // Orient player & gun
        let aimingLeft = cos(playerAimAngle) < 0
        playerNode.xScale = aimingLeft ? -1 : 1
        gunNode.position = CGPoint(
            x: playerNode.position.x + cos(playerAimAngle) * 14,
            y: playerNode.position.y + sin(playerAimAngle) * 14 - 3
        )
        gunNode.zRotation = playerAimAngle
        gunNode.yScale = aimingLeft ? -1 : 1

        // Shooting
        if fireCooldown > 0 { fireCooldown -= dt }
        if input.isFiring && fireCooldown <= 0 {
            fireCurrentWeapon()
        }

        // Wave spawning
        if !enemiesRemainingToSpawn.isEmpty {
            spawnTimer -= dt
            if spawnTimer <= 0 {
                let kind = enemiesRemainingToSpawn.removeFirst()
                spawnEnemy(kind)
                spawnTimer = max(0.28, 1.05 - Double(wave) * 0.05)
            }
        } else if enemies.isEmpty {
            waveClearDelay += dt
            if waveClearDelay >= 1.1 {
                openArmory()
                return
            }
        }

        updateEnemies(dt: dt)
        updateProjectiles(dt: dt)
        updatePickups(dt: dt)
        updateCamera(dt: dt)
        updateHUD()
    }

    // MARK: - Weapons & Shooting

    private func fireCurrentWeapon() {
        let stats = loadout.currentStats
        let wep = loadout.currentWeapon
        fireCooldown = stats.fireCooldown

        let muzzleDist: CGFloat = 28
        let muzzlePos = CGPoint(
            x: playerNode.position.x + cos(playerAimAngle) * muzzleDist,
            y: playerNode.position.y + sin(playerAimAngle) * muzzleDist - 2
        )

        let texKey = "\(stats.bulletCoreHex)_\(stats.bulletGlowHex)_\(stats.wideBullet)"
        let tex: SKTexture
        if let cached = bulletTextures[texKey] {
            tex = cached
        } else {
            tex = PixelArt.bulletTexture(core: stats.bulletCoreHex, glow: stats.bulletGlowHex, wide: stats.wideBullet)
            bulletTextures[texKey] = tex
        }

        let count = stats.projectileCount
        for i in 0..<count {
            let offset: CGFloat
            if count == 1 {
                offset = CGFloat.random(in: -stats.spreadRadians...stats.spreadRadians)
            } else {
                let frac = CGFloat(i) / CGFloat(count - 1) - 0.5
                offset = frac * stats.spreadRadians + CGFloat.random(in: -0.025...0.025)
            }
            let angle = playerAimAngle + offset
            let proj = ProjectileEntity(
                texture: tex,
                position: muzzlePos,
                angle: angle,
                speed: stats.projectileSpeed,
                damage: stats.damage,
                isPlayer: true,
                radius: stats.wideBullet ? 10 : 7,
                pierce: stats.pierceCount,
                knockback: stats.knockback
            )
            worldNode.addChild(proj.node)
            projectiles.append(proj)
        }

        spawnMuzzleFlash(at: muzzlePos, color: wep.accentColor)
        addShake(stats.screenShake)
        AudioEngine.shared.play(wep.soundEffect)
        input.playHaptic(intensity: stats.hapticIntensity, sharpness: 0.75, duration: 0.05)
    }

    // MARK: - Enemies

    private func spawnEnemy(_ kind: EnemyKind) {
        let hw = arenaSize.width / 2 - 48
        let hh = arenaSize.height / 2 - 48
        var pos = CGPoint.zero

        for _ in 0..<12 {
            let edge = Int.random(in: 0..<4)
            switch edge {
            case 0: pos = CGPoint(x: CGFloat.random(in: -hw...hw), y: hh)
            case 1: pos = CGPoint(x: CGFloat.random(in: -hw...hw), y: -hh)
            case 2: pos = CGPoint(x: -hw, y: CGFloat.random(in: -hh...hh))
            default: pos = CGPoint(x: hw, y: CGFloat.random(in: -hh...hh))
            }
            if hypot(pos.x - playerNode.position.x, pos.y - playerNode.position.y) > 260 {
                break
            }
        }

        let enemy = EnemyEntity(kind: kind, position: pos, wave: wave)
        worldNode.addChild(enemy.node)
        enemies.append(enemy)
    }

    private func updateEnemies(dt: TimeInterval) {
        let halfW = arenaSize.width / 2 - 28
        let halfH = arenaSize.height / 2 - 28

        for enemy in enemies {
            let dx = playerNode.position.x - enemy.node.position.x
            let dy = playerNode.position.y - enemy.node.position.y
            let dist = max(1, hypot(dx, dy))
            let nx = dx / dist
            let ny = dy / dist

            var moveX = nx * enemy.speed
            var moveY = ny * enemy.speed

            if enemy.kind == .drone {
                // Keep medium distance and strafe
                if dist < 210 {
                    moveX = -nx * enemy.speed * 0.7 + (-ny * enemy.speed * 0.6)
                    moveY = -ny * enemy.speed * 0.7 + (nx * enemy.speed * 0.6)
                } else if dist < 300 {
                    moveX = -ny * enemy.speed * 0.75
                    moveY = nx * enemy.speed * 0.75
                }
            }

            // Apply knockback decay
            enemy.knockbackVel.dx *= pow(0.06, CGFloat(dt))
            enemy.knockbackVel.dy *= pow(0.06, CGFloat(dt))

            enemy.node.position.x = max(-halfW, min(halfW, enemy.node.position.x + (moveX + enemy.knockbackVel.dx) * CGFloat(dt)))
            enemy.node.position.y = max(-halfH, min(halfH, enemy.node.position.y + (moveY + enemy.knockbackVel.dy) * CGFloat(dt)))

            // Hit flash timer
            if enemy.hitFlashTimer > 0 {
                enemy.hitFlashTimer -= dt
                if enemy.hitFlashTimer <= 0 {
                    enemy.node.colorBlendFactor = 0
                }
            }

            // Enemy shooting
            enemy.shootCooldown -= dt
            if enemy.shootCooldown <= 0 {
                let angle = atan2(dy, dx)
                switch enemy.kind {
                case .drone:
                    spawnEnemyBullet(from: enemy.node.position, angle: angle, speed: 310, damage: 12)
                    enemy.shootCooldown = max(1.1, 2.0 - Double(wave) * 0.05)

                case .brute:
                    for off in [-0.22, 0.0, 0.22] as [CGFloat] {
                        spawnEnemyBullet(from: enemy.node.position, angle: angle + off, speed: 280, damage: 14)
                    }
                    enemy.shootCooldown = 2.4

                case .boss:
                    enemy.phaseTimer += 1
                    if Int(enemy.phaseTimer) % 2 == 0 {
                        // Radial bullet ring
                        let spokes = 12
                        let base = CGFloat(enemy.phaseTimer) * 0.35
                        for s in 0..<spokes {
                            let a = base + (CGFloat(s) / CGFloat(spokes)) * (.pi * 2)
                            spawnEnemyBullet(from: enemy.node.position, angle: a, speed: 270, damage: 15)
                        }
                    } else {
                        // Aimed 5-shot fan
                        for off in [-0.36, -0.18, 0.0, 0.18, 0.36] as [CGFloat] {
                            spawnEnemyBullet(from: enemy.node.position, angle: angle + off, speed: 340, damage: 15)
                        }
                    }
                    enemy.shootCooldown = 1.25

                case .swarmer:
                    break
                }
            }

            // Contact damage with player
            if dist < enemy.radius + 16 {
                damagePlayer(enemy.contactDamage)
            }
        }
    }

    private func spawnEnemyBullet(from pos: CGPoint, angle: CGFloat, speed: CGFloat, damage: CGFloat) {
        let proj = ProjectileEntity(
            texture: enemyBulletTexture,
            position: pos,
            angle: angle,
            speed: speed,
            damage: damage,
            isPlayer: false,
            radius: 7,
            pierce: 0,
            knockback: 0,
            lifetime: 3.5
        )
        worldNode.addChild(proj.node)
        projectiles.append(proj)
    }

    // MARK: - Projectiles & Collisions

    private func updateProjectiles(dt: TimeInterval) {
        let hw = arenaSize.width / 2 + 20
        let hh = arenaSize.height / 2 + 20

        var keepProjectiles: [ProjectileEntity] = []
        var deadEnemyIDs: Set<UUID> = []

        for proj in projectiles {
            proj.lifetime -= dt
            proj.node.position.x += proj.velocity.dx * CGFloat(dt)
            proj.node.position.y += proj.velocity.dy * CGFloat(dt)

            let outOfBounds = abs(proj.node.position.x) > hw || abs(proj.node.position.y) > hh
            if proj.lifetime <= 0 || outOfBounds {
                proj.node.removeFromParent()
                continue
            }

            var consumed = false

            if proj.isPlayer {
                for enemy in enemies where !deadEnemyIDs.contains(enemy.id) {
                    if proj.hitEnemyIDs.contains(enemy.id) { continue }
                    let dist = hypot(proj.node.position.x - enemy.node.position.x, proj.node.position.y - enemy.node.position.y)
                    if dist < enemy.radius + proj.radius {
                        proj.hitEnemyIDs.insert(enemy.id)
                        enemy.hp -= proj.damage
                        enemy.updateHealthBar()

                        // Hit flash & knockback
                        enemy.node.color = .white
                        enemy.node.colorBlendFactor = 0.85
                        enemy.hitFlashTimer = 0.075

                        let vLen = max(1, hypot(proj.velocity.dx, proj.velocity.dy))
                        let kbFactor: CGFloat = enemy.kind == .boss ? 0.12 : (enemy.kind == .brute ? 0.35 : 1.0)
                        enemy.knockbackVel.dx += (proj.velocity.dx / vLen) * proj.knockback * kbFactor
                        enemy.knockbackVel.dy += (proj.velocity.dy / vLen) * proj.knockback * kbFactor

                        spawnFloatingText("\(Int(proj.damage))", at: enemy.node.position, color: .white)
                        spawnPixelBurst(at: proj.node.position, color: NSColor(red: 0.98, green: 0.85, blue: 0.3, alpha: 1), count: 4)
                        AudioEngine.shared.play(.hit)

                        if enemy.hp <= 0 {
                            deadEnemyIDs.insert(enemy.id)
                            handleEnemyDeath(enemy)
                        }

                        if proj.remainingPierce > 0 {
                            proj.remainingPierce -= 1
                        } else {
                            consumed = true
                            break
                        }
                    }
                }
            } else {
                let dist = hypot(proj.node.position.x - playerNode.position.x, proj.node.position.y - playerNode.position.y)
                if dist < 16 + proj.radius {
                    damagePlayer(proj.damage)
                    consumed = true
                }
            }

            if consumed {
                proj.node.removeFromParent()
            } else {
                keepProjectiles.append(proj)
            }
        }

        projectiles = keepProjectiles
        if !deadEnemyIDs.isEmpty {
            enemies.removeAll { deadEnemyIDs.contains($0.id) }
        }
    }

    private func handleEnemyDeath(_ enemy: EnemyEntity) {
        kills += 1
        score += enemy.scoreValue
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "PixelBlasterHighScore")
        }

        let burstColor: NSColor
        switch enemy.kind {
        case .swarmer: burstColor = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
        case .drone: burstColor = NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1)
        case .brute: burstColor = NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
        case .boss: burstColor = NSColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
        }

        spawnPixelBurst(at: enemy.node.position, color: burstColor, count: enemy.kind == .boss ? 28 : 10)
        addShake(enemy.kind == .boss ? 16 : (enemy.kind == .brute ? 7 : 3))
        AudioEngine.shared.play(.enemyDeath)
        if enemy.kind == .boss {
            input.playHaptic(intensity: 1.0, sharpness: 0.4, duration: 0.3)
        }

        // Drop scrap coins
        let coinCount = enemy.kind == .boss ? 8 : (enemy.kind == .brute ? 3 : 1)
        let perCoin = max(1, Int(ceil(Double(enemy.scrapValue) / Double(coinCount))))
        for _ in 0..<coinCount {
            let jitter = CGPoint(
                x: enemy.node.position.x + CGFloat.random(in: -22...22),
                y: enemy.node.position.y + CGFloat.random(in: -22...22)
            )
            let coin = PickupEntity(kind: .scrap(perCoin), position: jitter)
            worldNode.addChild(coin.node)
            pickups.append(coin)
        }

        // Occasional medkit drop
        let medChance = enemy.kind == .boss ? 1.0 : (enemy.kind == .brute ? 0.28 : 0.06)
        if Double.random(in: 0...1) < medChance {
            let med = PickupEntity(kind: .medkit(25), position: enemy.node.position)
            worldNode.addChild(med.node)
            pickups.append(med)
        }

        enemy.node.removeFromParent()
    }

    private func damagePlayer(_ amount: CGFloat) {
        guard invulnTimer <= 0, state == .playing else { return }
        playerHP = max(0, playerHP - amount)
        invulnTimer = 0.75
        addShake(10)
        AudioEngine.shared.play(.playerHurt)
        input.playHaptic(intensity: 0.85, sharpness: 0.35, duration: 0.18)
        spawnPixelBurst(at: playerNode.position, color: NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1), count: 10)
        updateHUD()

        if playerHP <= 0 {
            state = .gameOver
            showGameOverOverlay()
        }
    }

    // MARK: - Pickups

    private func updatePickups(dt: TimeInterval) {
        let magnetRadius: CGFloat = 115 + CGFloat(loadout.magnetLevel - 1) * 65
        let scrapBonusMult = 1.0 + Double(loadout.magnetLevel - 1) * 0.15

        var remaining: [PickupEntity] = []
        for item in pickups {
            item.lifetime -= dt
            item.bobPhase += CGFloat(dt) * 5.0
            if item.lifetime <= 0 {
                item.node.removeFromParent()
                continue
            }

            let dx = playerNode.position.x - item.node.position.x
            let dy = playerNode.position.y - item.node.position.y
            let dist = max(1, hypot(dx, dy))

            if dist < magnetRadius {
                let pullSpeed: CGFloat = 460
                item.node.position.x += (dx / dist) * pullSpeed * CGFloat(dt)
                item.node.position.y += (dy / dist) * pullSpeed * CGFloat(dt)
            } else {
                item.node.position.y += sin(item.bobPhase) * 0.35
            }

            if dist < 24 {
                switch item.kind {
                case .scrap(let val):
                    let gained = max(1, Int(round(Double(val) * scrapBonusMult)))
                    scrap += gained
                    spawnFloatingText("+\(gained)", at: item.node.position, color: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1))
                case .medkit(let heal):
                    playerHP = min(playerMaxHP, playerHP + heal)
                    spawnFloatingText("+\(Int(heal)) HP", at: item.node.position, color: NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1))
                }
                AudioEngine.shared.play(.pickup)
                item.node.removeFromParent()
            } else {
                remaining.append(item)
            }
        }
        pickups = remaining
    }

    // MARK: - Camera & VFX

    private func updateCamera(dt: TimeInterval) {
        let lerp: CGFloat = min(1.0, CGFloat(dt) * 8.5)
        var targetX = cameraNode.position.x + (playerNode.position.x - cameraNode.position.x) * lerp
        var targetY = cameraNode.position.y + (playerNode.position.y - cameraNode.position.y) * lerp

        // Clamp camera nicely to arena bounds if window is smaller than arena
        let maxCamX = max(0, (arenaSize.width - size.width) / 2 + 40)
        let maxCamY = max(0, (arenaSize.height - size.height) / 2 + 40)
        targetX = max(-maxCamX, min(maxCamX, targetX))
        targetY = max(-maxCamY, min(maxCamY, targetY))

        if shakeIntensity > 0.2 {
            targetX += CGFloat.random(in: -shakeIntensity...shakeIntensity)
            targetY += CGFloat.random(in: -shakeIntensity...shakeIntensity)
            shakeIntensity *= pow(0.015, CGFloat(dt))
        } else {
            shakeIntensity = 0
        }

        cameraNode.position = CGPoint(x: targetX, y: targetY)
    }

    private func addShake(_ amount: CGFloat) {
        shakeIntensity = min(20, max(shakeIntensity, amount))
    }

    private func spawnMuzzleFlash(at pos: CGPoint, color: NSColor) {
        let flash = SKShapeNode(rectOf: CGSize(width: 10, height: 10))
        flash.fillColor = .white
        flash.strokeColor = color
        flash.lineWidth = 2
        flash.position = pos
        flash.zPosition = 16
        worldNode.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.5, duration: 0.05), .fadeOut(withDuration: 0.05)]),
            .removeFromParent()
        ]))
    }

    private func spawnDashGhost() {
        let ghost = SKSpriteNode(texture: playerNode.texture)
        ghost.position = playerNode.position
        ghost.xScale = playerNode.xScale
        ghost.color = NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1)
        ghost.colorBlendFactor = 0.8
        ghost.alpha = 0.45
        ghost.zPosition = 9
        worldNode.addChild(ghost)
        ghost.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
    }

    private func spawnPixelBurst(at pos: CGPoint, color: NSColor, count: Int) {
        for _ in 0..<count {
            let p = SKShapeNode(rectOf: CGSize(width: 5, height: 5))
            p.fillColor = color
            p.strokeColor = .clear
            p.position = pos
            p.zPosition = 18
            worldNode.addChild(p)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 18...64)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist
            p.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: 0.24),
                    .fadeOut(withDuration: 0.24)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnFloatingText(_ text: String, at pos: CGPoint, color: NSColor) {
        let lbl = makeLabel(text, size: 12, color: color)
        lbl.position = CGPoint(x: pos.x + CGFloat.random(in: -8...8), y: pos.y + 14)
        lbl.zPosition = 25
        worldNode.addChild(lbl)
        lbl.run(.sequence([
            .group([
                .moveBy(x: 0, y: 24, duration: 0.42),
                .fadeOut(withDuration: 0.42)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Armory / Upgrade Shop

    private func openArmory() {
        // Clear remaining enemy bullets safely
        projectiles.forEach { $0.node.removeFromParent() }
        projectiles.removeAll()

        state = .armory
        selectedShopIndex = 0
        renderArmoryOverlay()
    }

    private func updateArmoryNavigation() {
        if input.menuNavX != 0 || input.menuNavY != 0 {
            let col = selectedShopIndex % 4
            let row = selectedShopIndex / 4
            let newCol = (col + input.menuNavX + 4) % 4
            let newRow = (row + input.menuNavY + 2) % 2
            selectedShopIndex = newRow * 4 + newCol
            AudioEngine.shared.play(.uiMove)
            renderArmoryOverlay()
        }

        if input.confirmPressed {
            activateShopItem(at: selectedShopIndex)
        } else if input.cancelPressed {
            startNextWaveFromArmory()
        }
    }

    private func activateShopItem(at index: Int) {
        guard index >= 0 && index < shopItems.count else { return }
        let item = shopItems[index]

        switch item {
        case .weapon(let type):
            if !loadout.canUpgrade(type) {
                loadout.select(type)
                gunNode.texture = type.gunTexture
                AudioEngine.shared.play(.uiConfirm)
                renderArmoryOverlay()
                updateHUD()
                return
            }
            let cost = loadout.upgradeCost(for: type)
            if scrap >= cost {
                scrap -= cost
                loadout.buyOrUpgrade(type)
                loadout.select(type)
                gunNode.texture = type.gunTexture
                AudioEngine.shared.play(.upgrade)
                input.playHaptic(intensity: 0.6, sharpness: 0.8, duration: 0.1)
                renderArmoryOverlay()
                updateHUD()
            } else {
                AudioEngine.shared.play(.hit)
                showToast("NEED \(cost) SCRAP!", color: NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
            }

        case .armor:
            let cost = loadout.armorUpgradeCost()
            if scrap >= cost {
                scrap -= cost
                loadout.upgradeArmor()
                playerMaxHP += 20
                playerHP = min(playerMaxHP, playerHP + 40)
                AudioEngine.shared.play(.upgrade)
                input.playHaptic(intensity: 0.5, sharpness: 0.7, duration: 0.1)
                renderArmoryOverlay()
                updateHUD()
            } else {
                AudioEngine.shared.play(.hit)
                showToast("NEED \(cost) SCRAP!", color: NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
            }

        case .speed:
            let cost = loadout.speedUpgradeCost()
            if scrap >= cost {
                scrap -= cost
                loadout.upgradeSpeed()
                AudioEngine.shared.play(.upgrade)
                input.playHaptic(intensity: 0.5, sharpness: 0.7, duration: 0.1)
                renderArmoryOverlay()
                updateHUD()
            } else {
                AudioEngine.shared.play(.hit)
                showToast("NEED \(cost) SCRAP!", color: NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
            }

        case .magnet:
            let cost = loadout.magnetUpgradeCost()
            if scrap >= cost {
                scrap -= cost
                loadout.upgradeMagnet()
                AudioEngine.shared.play(.upgrade)
                input.playHaptic(intensity: 0.5, sharpness: 0.7, duration: 0.1)
                renderArmoryOverlay()
                updateHUD()
            } else {
                AudioEngine.shared.play(.hit)
                showToast("NEED \(cost) SCRAP!", color: NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
            }

        case .nextWave:
            startNextWaveFromArmory()
        }
    }

    private func startNextWaveFromArmory() {
        AudioEngine.shared.play(.uiConfirm)
        overlayNode.removeAllChildren()
        state = .playing
        beginWave(wave + 1)
    }

    private func renderArmoryOverlay() {
        overlayNode.removeAllChildren()
        overlayNode.zPosition = 150
        shopCardFrames.removeAll()

        let backdrop = SKShapeNode(rectOf: CGSize(width: max(size.width, 1600), height: max(size.height, 1200)))
        backdrop.fillColor = NSColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 0.84)
        backdrop.strokeColor = .clear
        overlayNode.addChild(backdrop)

        let title = makeLabel("WAVE \(wave) CLEARED — ARMORY", size: 28, color: NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1))
        title.position = CGPoint(x: 0, y: 205)
        overlayNode.addChild(title)

        let scrapInfo = makeLabel("AVAILABLE SCRAP: \(scrap)   |   HP: \(Int(ceil(playerHP)))/\(Int(playerMaxHP))", size: 15, color: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1))
        scrapInfo.position = CGPoint(x: 0, y: 172)
        overlayNode.addChild(scrapInfo)

        let cardW: CGFloat = 195
        let cardH: CGFloat = 138
        let gapX: CGFloat = 16

        let startX = -(cardW * 2 + gapX * 1.5) + cardW / 2
        let rowY: [CGFloat] = [78, -80]

        for (idx, item) in shopItems.enumerated() {
            let col = idx % 4
            let row = idx / 4
            let cx = startX + CGFloat(col) * (cardW + gapX)
            let cy = rowY[row]
            let isSelected = idx == selectedShopIndex

            let cardRect = CGRect(x: cx - cardW / 2, y: cy - cardH / 2, width: cardW, height: cardH)
            shopCardFrames.append((idx, cardRect))

            let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 8)
            card.position = CGPoint(x: cx, y: cy)

            switch item {
            case .weapon(let wep):
                let unlocked = loadout.isUnlocked(wep)
                let lv = loadout.level(of: wep)
                let maxed = unlocked && lv >= WeaponLoadout.maxLevel
                let cost = loadout.upgradeCost(for: wep)
                let canAfford = scrap >= cost

                card.fillColor = NSColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 0.95)
                card.strokeColor = isSelected ? NSColor.white : (unlocked ? wep.accentColor : NSColor(white: 0.3, alpha: 0.8))
                card.lineWidth = isSelected ? 3.5 : 1.5
                overlayNode.addChild(card)

                let icon = SKSpriteNode(texture: wep.gunTexture)
                icon.setScale(1.1)
                icon.position = CGPoint(x: 0, y: 36)
                card.addChild(icon)

                let nameLbl = makeLabel(wep.name, size: 12, color: wep.accentColor)
                nameLbl.position = CGPoint(x: 0, y: 6)
                card.addChild(nameLbl)

                let pips = unlocked
                    ? String(repeating: "■", count: lv) + String(repeating: "□", count: WeaponLoadout.maxLevel - lv)
                    : "LOCKED"
                let pipLbl = makeLabel(pips, size: 11, color: unlocked ? NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1) : NSColor(white: 0.5, alpha: 1))
                pipLbl.position = CGPoint(x: 0, y: -12)
                card.addChild(pipLbl)

                let descLbl = makeLabel(loadout.nextUpgradeDescription(for: wep), size: 10, color: NSColor(white: 0.82, alpha: 1))
                descLbl.position = CGPoint(x: 0, y: -30)
                card.addChild(descLbl)

                let actionText = maxed ? (loadout.currentWeapon == wep ? "EQUIPPED" : "EQUIP") : (unlocked ? "UPGRADE: \(cost)" : "UNLOCK: \(cost)")
                let actionColor = maxed
                    ? NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1)
                    : (canAfford ? NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1) : NSColor(red: 0.94, green: 0.35, blue: 0.35, alpha: 1))
                let costLbl = makeLabel(actionText, size: 12, color: actionColor)
                costLbl.position = CGPoint(x: 0, y: -52)
                card.addChild(costLbl)

            case .armor:
                let cost = loadout.armorUpgradeCost()
                populateSuitCard(
                    card: card, isSelected: isSelected,
                    title: "SUIT ARMOR LV.\(loadout.armorLevel)",
                    desc: "+20 Max HP & Heal +40",
                    cost: cost,
                    accent: NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
                )
                overlayNode.addChild(card)

            case .speed:
                let cost = loadout.speedUpgradeCost()
                populateSuitCard(
                    card: card, isSelected: isSelected,
                    title: "THRUSTERS LV.\(loadout.speedLevel)",
                    desc: "+12% Speed & Faster Dash",
                    cost: cost,
                    accent: NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1)
                )
                overlayNode.addChild(card)

            case .magnet:
                let cost = loadout.magnetUpgradeCost()
                populateSuitCard(
                    card: card, isSelected: isSelected,
                    title: "MAGNET LV.\(loadout.magnetLevel)",
                    desc: "+Range & +15% Scrap Value",
                    cost: cost,
                    accent: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1)
                )
                overlayNode.addChild(card)

            case .nextWave:
                card.fillColor = NSColor(red: 0.08, green: 0.32, blue: 0.20, alpha: 0.95)
                card.strokeColor = isSelected ? .white : NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1)
                card.lineWidth = isSelected ? 3.5 : 2
                overlayNode.addChild(card)

                let goLbl = makeLabel("START WAVE \(wave + 1)", size: 15, color: .white)
                goLbl.position = CGPoint(x: 0, y: 12)
                card.addChild(goLbl)

                let subLbl = makeLabel("DEPLOY TO ARENA", size: 11, color: NSColor(red: 0.73, green: 0.97, blue: 0.82, alpha: 1))
                subLbl.position = CGPoint(x: 0, y: -12)
                card.addChild(subLbl)

                let hintLbl = makeLabel("[A / B / CLICK]", size: 10, color: NSColor(white: 0.85, alpha: 1))
                hintLbl.position = CGPoint(x: 0, y: -38)
                card.addChild(hintLbl)
            }
        }

        let footer = makeLabel("D-PAD / STICK / MOUSE: SELECT   •   A / ENTER / CLICK: BUY   •   B / ESC: NEXT WAVE", size: 11, color: NSColor(white: 0.72, alpha: 1))
        footer.position = CGPoint(x: 0, y: -182)
        overlayNode.addChild(footer)
    }

    private func populateSuitCard(card: SKShapeNode, isSelected: Bool, title: String, desc: String, cost: Int, accent: NSColor) {
        card.fillColor = NSColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 0.95)
        card.strokeColor = isSelected ? .white : accent
        card.lineWidth = isSelected ? 3.5 : 1.5

        let titleLbl = makeLabel(title, size: 13, color: accent)
        titleLbl.position = CGPoint(x: 0, y: 26)
        card.addChild(titleLbl)

        let descLbl = makeLabel(desc, size: 11, color: NSColor(white: 0.85, alpha: 1))
        descLbl.position = CGPoint(x: 0, y: -4)
        card.addChild(descLbl)

        let canAfford = scrap >= cost
        let costLbl = makeLabel("UPGRADE: \(cost)", size: 12, color: canAfford ? NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1) : NSColor(red: 0.94, green: 0.35, blue: 0.35, alpha: 1))
        costLbl.position = CGPoint(x: 0, y: -42)
        card.addChild(costLbl)
    }

    // MARK: - Title, Pause & Game Over Overlays

    private func refreshCurrentOverlay() {
        switch state {
        case .title: showTitleOverlay()
        case .armory: renderArmoryOverlay()
        case .paused: showPauseOverlay()
        case .gameOver: showGameOverOverlay()
        case .playing: break
        }
    }

    private func showTitleOverlay() {
        state = .title
        hudNode.isHidden = true
        reticleNode.isHidden = true
        overlayNode.removeAllChildren()
        overlayNode.zPosition = 150

        let bg = SKShapeNode(rectOf: CGSize(width: max(size.width, 1600), height: max(size.height, 1200)))
        bg.fillColor = NSColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 0.92)
        bg.strokeColor = .clear
        overlayNode.addChild(bg)

        let hero = SKSpriteNode(texture: PixelArt.playerFrames[0])
        hero.setScale(2.0)
        hero.position = CGPoint(x: 0, y: 145)
        overlayNode.addChild(hero)

        let title = makeLabel("PIXEL BLASTER", size: 46, color: NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1))
        title.position = CGPoint(x: 0, y: 62)
        overlayNode.addChild(title)

        let sub = makeLabel("TWIN-STICK PIXEL SHOOTER  •  UPGRADEABLE ARSENAL", size: 14, color: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1))
        sub.position = CGPoint(x: 0, y: 30)
        overlayNode.addChild(sub)

        let ctrlStatus = input.controllerName != nil
            ? "CONTROLLER READY: \(input.controllerName!.uppercased())"
            : "NO CONTROLLER DETECTED — PAIR BLUETOOTH/USB GAMEPAD OR USE KEYBOARD + MOUSE"
        let ctrlLbl = makeLabel(ctrlStatus, size: 12, color: input.controllerName != nil ? NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1) : NSColor(white: 0.7, alpha: 1))
        ctrlLbl.position = CGPoint(x: 0, y: -10)
        overlayNode.addChild(ctrlLbl)

        let controls1 = makeLabel("CONTROLLER:  L-STICK Move  •  R-STICK Aim  •  RT/R1 Fire  •  LT/A Dash  •  LB/X Swap Gun", size: 12, color: NSColor(white: 0.85, alpha: 1))
        controls1.position = CGPoint(x: 0, y: -56)
        overlayNode.addChild(controls1)

        let controls2 = makeLabel("KEYBOARD:    WASD Move  •  MOUSE Aim & Shoot  •  SPACE Dash  •  1-4 / Q,E Swap Gun  •  M Mute", size: 12, color: NSColor(white: 0.68, alpha: 1))
        controls2.position = CGPoint(x: 0, y: -80)
        overlayNode.addChild(controls2)

        let startLbl = makeLabel("PRESS [A] / [ENTER] OR CLICK TO START", size: 20, color: .white)
        startLbl.position = CGPoint(x: 0, y: -140)
        startLbl.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.6), .fadeAlpha(to: 1.0, duration: 0.6)])))
        overlayNode.addChild(startLbl)

        if highScore > 0 {
            let hi = makeLabel("HIGH SCORE: \(highScore)", size: 13, color: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1))
            hi.position = CGPoint(x: 0, y: -185)
            overlayNode.addChild(hi)
        }
    }

    private func showPauseOverlay() {
        overlayNode.removeAllChildren()
        overlayNode.zPosition = 150

        let bg = SKShapeNode(rectOf: CGSize(width: max(size.width, 1600), height: max(size.height, 1200)))
        bg.fillColor = NSColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 0.78)
        bg.strokeColor = .clear
        overlayNode.addChild(bg)

        let title = makeLabel("PAUSED", size: 36, color: .white)
        title.position = CGPoint(x: 0, y: 40)
        overlayNode.addChild(title)

        let resume = makeLabel("PRESS [START / A / ESC / ENTER] TO RESUME", size: 15, color: NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1))
        resume.position = CGPoint(x: 0, y: -16)
        overlayNode.addChild(resume)

        let quit = makeLabel("PRESS [B] TO RETURN TO TITLE", size: 13, color: NSColor(white: 0.72, alpha: 1))
        quit.position = CGPoint(x: 0, y: -48)
        overlayNode.addChild(quit)
    }

    private func showGameOverOverlay() {
        overlayNode.removeAllChildren()
        overlayNode.zPosition = 150

        let bg = SKShapeNode(rectOf: CGSize(width: max(size.width, 1600), height: max(size.height, 1200)))
        bg.fillColor = NSColor(red: 0.08, green: 0.02, blue: 0.04, alpha: 0.85)
        bg.strokeColor = .clear
        overlayNode.addChild(bg)

        let title = makeLabel("MISSION FAILED", size: 42, color: NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
        title.position = CGPoint(x: 0, y: 86)
        overlayNode.addChild(title)

        let stats = makeLabel("WAVE REACHED: \(wave)   •   SCORE: \(score)   •   KILLS: \(kills)", size: 16, color: .white)
        stats.position = CGPoint(x: 0, y: 28)
        overlayNode.addChild(stats)

        let hi = makeLabel("HIGH SCORE: \(highScore)", size: 15, color: NSColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1))
        hi.position = CGPoint(x: 0, y: -6)
        overlayNode.addChild(hi)

        let retry = makeLabel("PRESS [A] / [ENTER] OR CLICK TO PLAY AGAIN", size: 18, color: NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1))
        retry.position = CGPoint(x: 0, y: -74)
        retry.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.55), .fadeAlpha(to: 1.0, duration: 0.55)])))
        overlayNode.addChild(retry)
    }

    // MARK: - Mouse & Keyboard Forwarding

    override func keyDown(with event: NSEvent) {
        input.keyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        input.keyUp(event)
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = event.location(in: self)
        input.mouseMoved(to: loc)

        if state == .armory {
            let camLoc = convert(loc, to: overlayNode)
            for card in shopCardFrames where card.frame.contains(camLoc) {
                if selectedShopIndex != card.index {
                    selectedShopIndex = card.index
                    renderArmoryOverlay()
                }
                break
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        input.mouseMoved(to: event.location(in: self))
    }

    override func mouseDown(with event: NSEvent) {
        let loc = event.location(in: self)
        input.mouseMoved(to: loc)
        input.isMouseDown = true

        if state == .title || state == .gameOver {
            AudioEngine.shared.play(.uiConfirm)
            startNewGame()
        } else if state == .armory {
            let camLoc = convert(loc, to: overlayNode)
            for card in shopCardFrames where card.frame.contains(camLoc) {
                selectedShopIndex = card.index
                activateShopItem(at: card.index)
                break
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        input.isMouseDown = false
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, size: CGFloat, color: NSColor) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.text = text
        lbl.fontSize = size
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        return lbl
    }
}
