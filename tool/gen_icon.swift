// Generates the app icon: a waveform of seven rounded coral-to-pink bars on
// an indigo-to-violet ground, drawn with CoreGraphics so it needs nothing
// beyond Xcode's toolchain.
//
//   swift tool/gen_icon.swift
//
// Writes every size in ios/Runner/Assets.xcassets/AppIcon.appiconset/ and
// the Android mipmap ic_launcher.png files. The bitmap is opaque and fills
// the whole square: iOS rounds the corners itself, Android launchers mask it.
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Draws the icon at `size` px. Coordinates are a 1000-unit square, y up.
func draw(size: Int) -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let s = CGFloat(size) / 1000
    ctx.scaleBy(x: s, y: s)

    // Ground: deep indigo to violet, corner to corner.
    let ground = CGGradient(colorsSpace: space,
                            colors: [color(0x1B1440), color(0x5B2A86)] as CFArray,
                            locations: [0, 1])!
    ctx.drawLinearGradient(ground, start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: 1000, y: 1000), options: [])

    // Seven rounded bars, mirrored about the middle line like a waveform,
    // clipped out of one warm gradient (coral at the bottom to pink on top).
    let heights: [CGFloat] = [180, 360, 560, 300, 640, 420, 220]
    let barWidth: CGFloat = 72, gap: CGFloat = 38
    let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    let bars = CGMutablePath()
    for (i, h) in heights.enumerated() {
        let x = (1000 - total) / 2 + CGFloat(i) * (barWidth + gap)
        bars.addRoundedRect(in: CGRect(x: x, y: 500 - h / 2, width: barWidth, height: h),
                            cornerWidth: barWidth / 2, cornerHeight: barWidth / 2)
    }
    ctx.saveGState()
    ctx.addPath(bars)
    ctx.clip()
    let warm = CGGradient(colorsSpace: space,
                          colors: [color(0xFF8A65), color(0xFF9EC4)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(warm, start: CGPoint(x: 0, y: 180),
                           end: CGPoint(x: 0, y: 820), options: [])
    ctx.restoreGState()
    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let png = NSBitmapImageRep(cgImage: image)
        .representation(using: .png, properties: [:])!
    try! png.write(to: url)
    print("wrote", url.path.replacingOccurrences(of: root.path + "/", with: ""))
}

let iosDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let iosSizes: [(String, Int)] = [
    ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60), ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120), ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180), ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152), ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]
for (name, size) in iosSizes {
    write(draw(size: size), to: iosDir.appendingPathComponent(name))
}
for (dir, size) in [("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
                    ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192)] {
    write(draw(size: size), to: root.appendingPathComponent(
        "android/app/src/main/res/\(dir)/ic_launcher.png"))
}
