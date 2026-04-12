import AppKit

enum BrandAssets {
    static var brandMark: NSImage? {
        loadImage(named: "brandmark", ext: "png")
    }

    static var menuBarTemplate: NSImage? {
        loadImage(named: "menubar-template", ext: "png")
    }

    private static func loadImage(named name: String, ext: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
