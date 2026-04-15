import AppKit

enum AppIcon {
    @MainActor
    static func apply() {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 360),
            .paragraphStyle: paragraph,
        ]

        let text = NSAttributedString(string: "🧲", attributes: attributes)
        text.draw(in: NSRect(x: 0, y: 52, width: size.width, height: size.height))
        image.unlockFocus()

        NSApplication.shared.applicationIconImage = image
    }
}
