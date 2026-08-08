#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")
let preview = resources.appendingPathComponent("AppIcon.png")
let fileManager = FileManager.default

try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func drawVideoScreenIcon(size: Int, name: String) throws {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate bitmap (name)"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let margin = CGFloat(size) * (92.0 / 1024.0)
    let bodyRect = rect.insetBy(dx: margin, dy: margin)
    let corner = CGFloat(size) * 0.19
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: corner, yRadius: corner)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.18, green: 0.28, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.66, blue: 0.72, alpha: 1)
    ])?.draw(in: body, angle: 135)

    NSColor.white.withAlphaComponent(0.22).setStroke()
    body.lineWidth = max(1, CGFloat(size) * 0.012)
    body.stroke()

    let screenRect = bodyRect.insetBy(dx: CGFloat(size) * 0.17, dy: CGFloat(size) * 0.24)
    let screen = NSBezierPath(roundedRect: screenRect, xRadius: CGFloat(size) * 0.065, yRadius: CGFloat(size) * 0.065)
    NSColor.white.withAlphaComponent(0.94).setStroke()
    screen.lineWidth = max(2, CGFloat(size) * 0.046)
    screen.stroke()

    let playCenter = NSPoint(x: screenRect.midX, y: screenRect.midY + screenRect.height * 0.02)
    let playRadius = CGFloat(size) * 0.105
    let play = NSBezierPath()
    play.move(to: NSPoint(x: playCenter.x - playRadius * 0.45, y: playCenter.y - playRadius))
    play.line(to: NSPoint(x: playCenter.x + playRadius * 0.80, y: playCenter.y))
    play.line(to: NSPoint(x: playCenter.x - playRadius * 0.45, y: playCenter.y + playRadius))
    play.close()
    NSColor.white.withAlphaComponent(0.95).setFill()
    play.fill()

    let stand = NSBezierPath()
    stand.move(to: NSPoint(x: bodyRect.midX - CGFloat(size) * 0.13, y: bodyRect.minY + CGFloat(size) * 0.13))
    stand.line(to: NSPoint(x: bodyRect.midX + CGFloat(size) * 0.13, y: bodyRect.minY + CGFloat(size) * 0.13))
    NSColor.white.withAlphaComponent(0.68).setStroke()
    stand.lineWidth = max(2, CGFloat(size) * 0.034)
    stand.lineCapStyle = .round
    stand.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to render icon (name)"])
    }
    try png.write(to: iconset.appendingPathComponent(name), options: .atomic)
}

for variant in variants {
    try drawVideoScreenIcon(size: variant.0, name: variant.1)
}

try? fileManager.removeItem(at: output)
try? fileManager.removeItem(at: preview)
try fileManager.copyItem(at: iconset.appendingPathComponent("icon_512x512@2x.png"), to: preview)

let icnsChunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

var chunks = Data()
for (type, fileName) in icnsChunks {
    let png = try Data(contentsOf: iconset.appendingPathComponent(fileName))
    chunks.append(type.data(using: .ascii)!)
    appendBigEndian(UInt32(png.count + 8), to: &chunks)
    chunks.append(png)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(chunks.count + 8), to: &icns)
icns.append(chunks)
try icns.write(to: output, options: .atomic)

print(output.path)
