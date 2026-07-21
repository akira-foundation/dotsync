import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px)

    let inset = s * 0.085
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors =
        [
            NSColor(srgbRed: 0.58, green: 0.29, blue: 0.96, alpha: 1).cgColor,
            NSColor(srgbRed: 0.36, green: 0.13, blue: 0.75, alpha: 1).cgColor,
        ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    ctx.restoreGState()

    var config = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .semibold)
    config = config.applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(
        systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let side = s * 0.52
        let scale = side / max(symbol.size.width, symbol.size.height)
        let width = symbol.size.width * scale
        let height = symbol.size.height * scale
        symbol.draw(
            in: CGRect(x: (s - width) / 2, y: (s - height) / 2, width: width, height: height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let variants: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]
for (base, scale) in variants {
    let suffix = scale == 2 ? "@2x" : ""
    let name = "\(outDir)/icon_\(base)x\(base)\(suffix).png"
    try! render(base * scale).write(to: URL(fileURLWithPath: name))
}
print("iconset written to \(outDir)")
