import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fputs("usage: generate-emoji-icon.swift <output-iconset-dir> <emoji>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let emoji = CommandLine.arguments[2]
let fileManager = FileManager.default

try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconEntries: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (pixelSize, fileName) in iconEntries {
    let canvasSize = NSSize(width: pixelSize, height: pixelSize)
    let image = NSImage(size: canvasSize)

    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let font = NSFont.systemFont(ofSize: CGFloat(pixelSize) * 0.74)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle,
    ]

    let attributed = NSAttributedString(string: emoji, attributes: attributes)
    let bounds = attributed.boundingRect(
        with: NSSize(width: canvasSize.width, height: canvasSize.height),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )

    let drawRect = NSRect(
        x: 0,
        y: (canvasSize.height - bounds.height) / 2 - CGFloat(pixelSize) * 0.03,
        width: canvasSize.width,
        height: bounds.height
    )
    attributed.draw(in: drawRect)
    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "MountGuardIcon", code: 1)
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(fileName))
}
