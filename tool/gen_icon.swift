// Generates the app icon: a pink play triangle over three waves (the pink
// noise overlay) on a dark plum ground, drawn with CoreGraphics so it needs
// nothing beyond Xcode's toolchain.
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

    let ground = CGGradient(colorsSpace: space,
                            colors: [color(0x3B2230), color(0x170F14)] as CFArray,
                            locations: [0, 1])!
    ctx.drawLinearGradient(ground, start: CGPoint(x: 0, y: 1000),
                           end: CGPoint(x: 0, y: 0), options: [])

    // Play triangle with rounded corners (a thick round-joined stroke of the
    // same colour around the filled shape does the rounding).
    let pink = color(0xF2A7C3)
    let tri = CGMutablePath()
    tri.move(to: CGPoint(x: 400, y: 800))
    tri.addLine(to: CGPoint(x: 400, y: 470))
    tri.addLine(to: CGPoint(x: 680, y: 635))
    tri.closeSubpath()
    ctx.setLineJoin(.round)
    ctx.setLineWidth(70)
    ctx.setStrokeColor(pink)
    ctx.setFillColor(pink)
    ctx.addPath(tri)
    ctx.drawPath(using: .fillStroke)

    // Three waves underneath, fading downwards.
    ctx.setLineCap(.round)
    ctx.setLineWidth(38)
    for (i, alpha) in [0.95, 0.6, 0.32].enumerated() {
        let y = 330 - CGFloat(i) * 85
        let wave = CGMutablePath()
        wave.move(to: CGPoint(x: 220, y: y))
        var x: CGFloat = 220
        for k in 0..<4 {
            let up: CGFloat = k % 2 == 0 ? 42 : -42
            wave.addQuadCurve(to: CGPoint(x: x + 140, y: y),
                              control: CGPoint(x: x + 70, y: y + up))
            x += 140
        }
        ctx.addPath(wave)
        ctx.setStrokeColor(color(0xF2A7C3, alpha))
        ctx.strokePath()
    }
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
