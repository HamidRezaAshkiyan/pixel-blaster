import AppKit
import SpriteKit

struct PixelColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8

    init(_ hex: UInt32, alpha: UInt8 = 255) {
        self.r = UInt8((hex >> 16) & 0xFF)
        self.g = UInt8((hex >> 8) & 0xFF)
        self.b = UInt8(hex & 0xFF)
        self.a = alpha
    }

    static let clear = PixelColor(0x000000, alpha: 0)
}

enum PixelArt {
    /// Converts a string grid (rows of characters) into a crisp nearest-neighbor SKTexture.
    static func texture(from grid: [String], palette: [Character: PixelColor], scale: Int = 1) -> SKTexture {
        let height = grid.count
        let width = grid.first?.count ?? 1
        let outW = width * scale
        let outH = height * scale

        var bytes = [UInt8](repeating: 0, count: outW * outH * 4)

        for y in 0..<height {
            let row = Array(grid[y])
            for x in 0..<min(width, row.count) {
                let ch = row[x]
                guard let color = palette[ch], color.a > 0 else { continue }
                for sy in 0..<scale {
                    for sx in 0..<scale {
                        let px = x * scale + sx
                        let py = y * scale + sy
                        let idx = (py * outW + px) * 4
                        bytes[idx] = color.r
                        bytes[idx + 1] = color.g
                        bytes[idx + 2] = color.b
                        bytes[idx + 3] = color.a
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cgImage = CGImage(
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: outW * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let tex = SKTexture(cgImage: cgImage)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Cached Textures

    static let playerFrames: [SKTexture] = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0D1117), // outline
            "H": PixelColor(0x3B82F6), // helmet blue
            "h": PixelColor(0x60A5FA), // helmet highlight
            "V": PixelColor(0x38BDF8), // visor cyan
            "v": PixelColor(0xE0F2FE), // visor glint
            "B": PixelColor(0x1E293B), // dark suit
            "S": PixelColor(0x475569), // armor chest
            "C": PixelColor(0xF59E0B), // belt/accent gold
            "L": PixelColor(0x0F172A), // boots
        ]
        let frame1 = [
            "....OOOOOO....",
            "...OhhhhhHO...",
            "..OhHHVVVVHO..",
            "..OHHVvVVVHO..",
            "..OHHHHHHHHO..",
            "...OOOOOOOO...",
            "..OOBSSSSBOO..",
            "..OBSSCCSSBO..",
            "..OBBSSSSBBO..",
            "...OBBBBBBO...",
            "...OOB..BOO...",
            "...OLL..LLO...",
            "...OOO..OOO...",
            "..............",
        ]
        let frame2 = [
            "..............",
            "....OOOOOO....",
            "...OhhhhhHO...",
            "..OhHHVVVVHO..",
            "..OHHVvVVVHO..",
            "..OHHHHHHHHO..",
            "...OOOOOOOO...",
            "..OOBSSSSBOO..",
            "..OBSSCCSSBO..",
            "..OBBSSSSBBO..",
            "...OBBBBBBO...",
            "..OOLL..LLOO..",
            "..OOO....OOO..",
            "..............",
        ]
        return [
            texture(from: frame1, palette: palette, scale: 3),
            texture(from: frame2, palette: palette, scale: 3)
        ]
    }()

    static let gunPistol: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0B0F19),
            "M": PixelColor(0x94A3B8),
            "D": PixelColor(0x475569),
            "C": PixelColor(0x38BDF8),
            "G": PixelColor(0x334155),
        ]
        let grid = [
            "..OOOOOOOO.",
            ".OMMMMMMMCO",
            ".ODDDDDDDDO",
            ".OGGOOOOOO.",
            ".OGGO......",
            "..OO.......",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let gunShotgun: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0B0F19),
            "M": PixelColor(0xCBD5E1),
            "D": PixelColor(0x475569),
            "W": PixelColor(0xB45309),
            "w": PixelColor(0xD97706),
            "R": PixelColor(0xEF4444),
        ]
        let grid = [
            "....OOOOOOOOOO",
            ".OOOMMMMMMMMRO",
            "OwwWDDDDDDDDDO",
            "OwwWOOwwWOOOO.",
            ".OOOO.OOO.....",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let gunSMG: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0B0F19),
            "M": PixelColor(0x64748B),
            "P": PixelColor(0xA855F7),
            "p": PixelColor(0xE879F9),
            "D": PixelColor(0x1E293B),
        ]
        let grid = [
            "..OOOOOOOOOO.",
            ".OMMMppMMMMMO",
            "OODDDPPDDDDDO",
            ".OODDOOODDOO.",
            "..OOD...OD...",
            "...OO...OO...",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let gunRailgun: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0B0F19),
            "M": PixelColor(0xE2E8F0),
            "D": PixelColor(0x334155),
            "C": PixelColor(0x06B6D4),
            "c": PixelColor(0x67E8F9),
            "Y": PixelColor(0xFACC15),
        ]
        let grid = [
            "..OOOOOOOOOOOOOO",
            ".OMMMccccMMMMMCO",
            "OODDDCCCCDDDDDCO",
            ".OMMMYccYMMMMMCO",
            ".OODDOOOOOOOOOOO",
            "..OOO...........",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let enemySwarmer: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x09110A),
            "G": PixelColor(0x22C55E),
            "g": PixelColor(0x86EFAC),
            "D": PixelColor(0x15803D),
            "E": PixelColor(0xEF4444),
            "W": PixelColor(0xFFFFFF),
        ]
        let grid = [
            "...OOOOOO...",
            "..OggGGGG0..".replacingOccurrences(of: "0", with: "O"),
            ".OgGGGGGGGO.",
            ".OGEWGGWEGO.",
            ".OGEEGGEEGO.",
            ".OGGGGGGGGO.",
            ".ODDDDDDDDO.",
            "..ODDOODDO..",
            ".OOD....DOO.",
            ".OO......OO.",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let enemyDrone: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0D0A1A),
            "P": PixelColor(0x9333EA),
            "p": PixelColor(0xC084FC),
            "D": PixelColor(0x581C87),
            "R": PixelColor(0xF43F5E),
            "Y": PixelColor(0xFDE047),
        ]
        let grid = [
            "....OOOO....",
            "..OOppPPOO..",
            ".OpPPPPPPpO.",
            "OOPPPRRPPPOO",
            "ODPPRYYRPPDO",
            "OOPPPRRPPPOO",
            ".ODDDDDDDDO.",
            "..OODDDDOO..",
            "...O.OO.O...",
            "............",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let enemyBrute: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x140A0A),
            "R": PixelColor(0xDC2626),
            "r": PixelColor(0xF87171),
            "D": PixelColor(0x7F1D1D),
            "M": PixelColor(0x64748B),
            "Y": PixelColor(0xFACC15),
        ]
        let grid = [
            "...OOOOOOOO...",
            "..OrrRRRRrrO..",
            ".ORMMMMMMMMRO.",
            ".ORMYYMMYYMRO.",
            "OORRRRRRRRRROO",
            "ORrRRRRRRRRrRO",
            "ORRDDDDDDDDRRO",
            "ORRDMMMMMMDRRO",
            ".OODDDDDDDDOO.",
            "..ODDD..DDDO..",
            "..OMMM..MMMO..",
            "..OOOO..OOOO..",
        ]
        return texture(from: grid, palette: palette, scale: 4)
    }()

    static let enemyBoss: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x09050A),
            "R": PixelColor(0xB91C1C),
            "r": PixelColor(0xEF4444),
            "G": PixelColor(0xF59E0B),
            "g": PixelColor(0xFDE047),
            "D": PixelColor(0x450A0A),
            "M": PixelColor(0x334155),
            "C": PixelColor(0x22D3EE),
        ]
        let grid = [
            "....OOOOOOOOOO....",
            "..OOgGGrrrrGGgOO..",
            ".OgGGRRRRRRRRGGgO.",
            ".OGRRMMMMMMMMRRGO.",
            "OORRMCCCMMCCCMRROO",
            "ORrRMCCCMMCCCMRrRO",
            "ORRRMMMMMMMMMMRRRO",
            "ORRRDDDDDDDDDDRRRO",
            "ORRDGDDGDDGDDGDRRO",
            ".OORDDDDDDDDDDROO.",
            ".OORRRRRRRRRRRROO.",
            "..OODDD....DDDOO..",
            "..OOMMM....MMMOO..",
            "...OOOO....OOOO...",
        ]
        return texture(from: grid, palette: palette, scale: 5)
    }()

    static let scrapCoin: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x422006),
            "Y": PixelColor(0xFACC15),
            "y": PixelColor(0xFEF08A),
            "G": PixelColor(0xCA8A04),
        ]
        let grid = [
            "..OOOO..",
            ".OyyYYO.",
            "OyYYYYGO",
            "OyYGGYGO",
            "OyYYYYGO",
            ".OYYYYO.",
            "..OOOO..",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let medkit: SKTexture = {
        let palette: [Character: PixelColor] = [
            "O": PixelColor(0x0F172A),
            "W": PixelColor(0xF8FAFC),
            "R": PixelColor(0xEF4444),
            "S": PixelColor(0xCBD5E1),
        ]
        let grid = [
            ".OOOOOOO.",
            "OWWWRWWWO",
            "OWWWRWWWO",
            "OWRRRRRWO",
            "OWWWRWWWO",
            "OSSSSSSSO",
            ".OOOOOOO.",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static let reticle: SKTexture = {
        let palette: [Character: PixelColor] = [
            "W": PixelColor(0x38BDF8),
            "C": PixelColor(0xFFFFFF),
        ]
        let grid = [
            "....W....",
            "....W....",
            ".........",
            ".........",
            "WW..C..WW",
            ".........",
            ".........",
            "....W....",
            "....W....",
        ]
        return texture(from: grid, palette: palette, scale: 3)
    }()

    static func bulletTexture(core: UInt32, glow: UInt32, wide: Bool = false) -> SKTexture {
        let palette: [Character: PixelColor] = [
            "G": PixelColor(glow),
            "C": PixelColor(core),
            "W": PixelColor(0xFFFFFF),
        ]
        let grid: [String] = wide ? [
            ".GGGGGGGG.",
            "GCCCCCCCCG",
            "GCWWWWWWCG",
            "GCCCCCCCCG",
            ".GGGGGGGG.",
        ] : [
            ".GGG.",
            "GCCCG",
            "GCWCG",
            "GCCCG",
            ".GGG.",
        ]
        return texture(from: grid, palette: palette, scale: 2)
    }

    static let floorTile: SKTexture = {
        let palette: [Character: PixelColor] = [
            "A": PixelColor(0x0F172A),
            "B": PixelColor(0x131C31),
            "L": PixelColor(0x1E293B),
            "D": PixelColor(0x0B1120),
        ]
        var grid: [String] = []
        for y in 0..<16 {
            var row = ""
            for x in 0..<16 {
                if x == 0 || y == 0 {
                    row.append("L")
                } else if (x == 5 && y == 10) || (x == 11 && y == 4) {
                    row.append("D")
                } else if (x + y) % 7 == 0 {
                    row.append("B")
                } else {
                    row.append("A")
                }
            }
            grid.append(row)
        }
        return texture(from: grid, palette: palette, scale: 4)
    }()
}
