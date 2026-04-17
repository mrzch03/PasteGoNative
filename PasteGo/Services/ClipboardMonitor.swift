import AppKit
import CryptoKit
import Foundation

/// Monitors the system pasteboard for changes and saves new items to the database
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastTextHash: String = ""
    private var lastImageHash: String = ""
    private var suppressedChangeCount = 0
    private let clipRepo: ClipRepository

    /// Called on the main thread when a new clip is inserted
    var onNewClip: ((ClipItem) -> Void)?

    init(clipRepo: ClipRepository) {
        self.clipRepo = clipRepo
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.clipboardPollInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func processClipboardNow() {
        checkClipboard()
    }

    func suppressNextChanges(_ count: Int) {
        suppressedChangeCount = max(suppressedChangeCount, count)
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if suppressedChangeCount > 0 {
            suppressedChangeCount -= 1
            return
        }

        // Check for text
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let hash = sha256(text)
            if hash != lastTextHash {
                lastTextHash = hash
                let clipType = ContentTypeDetector.detect(text)
                let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

                let item = ClipItem(
                    content: text,
                    contentHash: hash,
                    clipType: clipType,
                    sourceApp: sourceApp
                )

                do {
                    let isNew = try clipRepo.insert(item)
                    if isNew {
                        DispatchQueue.main.async { [weak self] in
                            self?.onNewClip?(item)
                        }
                    }
                } catch {
                    print("Failed to insert clip: \(error)")
                }
            }
        }

        // Check for image
        if let tiffData = pasteboard.data(forType: .tiff),
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let hash = sha256Bytes(pngData)
            if hash != lastImageHash {
                lastImageHash = hash
                if let imagePath = saveImage(pngData: pngData, hash: hash, width: bitmap.pixelsWide, height: bitmap.pixelsHigh) {
                    let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
                    let item = ClipItem(
                        content: "[图片 \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)]",
                        contentHash: hash,
                        clipType: .image,
                        sourceApp: sourceApp,
                        imagePath: imagePath
                    )

                    do {
                        let isNew = try clipRepo.insert(item)
                        if isNew {
                            DispatchQueue.main.async { [weak self] in
                                self?.onNewClip?(item)
                            }
                        }
                    } catch {
                        print("Failed to insert image clip: \(error)")
                    }
                }
            }
        }
    }

    private func saveImage(pngData: Data, hash: String, width: Int, height: Int) -> String? {
        let dir = DatabaseManager.imagesDirectory
        let filename = String(hash.prefix(16)) + ".png"
        let path = dir.appendingPathComponent(filename)

        do {
            try pngData.write(to: path)
            return path.path
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Bytes(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
