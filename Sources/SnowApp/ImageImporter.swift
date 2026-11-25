import AppKit
import ImageIO
import UniformTypeIdentifiers
import Vision
import CoreImage

enum ImportedAssets {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Snow", isDirectory: true)
    }
    static func url(for placement: ImportPlacement) -> URL { directory.appendingPathComponent(placement.rawValue + ".png") }
    static func image(for placement: ImportPlacement) -> NSImage? { NSImage(contentsOf: url(for: placement)) }

    static func decode(_ url: URL) throws -> CGImage {
        let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0, bytes <= ImageImportPolicy.maximumBytes else { throw ImportFailure.invalidSize }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String?,
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = metadata[kCGImagePropertyPixelWidth as String] as? Int,
              let height = metadata[kCGImagePropertyPixelHeight as String] as? Int,
              ImageImportPolicy.accepts(byteCount: bytes, type: type, width: width, height: height),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: ImageImportPolicy.maximumDimension,
                kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw ImportFailure.invalidImage }
        return image
    }
    static func png(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw ImportFailure.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ImportFailure.invalidImage }
        return data as Data
    }
    static func save(_ image: CGImage, as placement: ImportPlacement, directory target: URL = directory) throws {
        guard image.width <= ImageImportPolicy.maximumDimension, image.height <= ImageImportPolicy.maximumDimension else { throw ImportFailure.invalidImage }
        let data = try png(image)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try data.write(to: target.appendingPathComponent(placement.rawValue + ".png"), options: .atomic)
    }
}

enum ImportFailure: LocalizedError {
    case invalidSize, invalidImage, noSubject
    var errorDescription: String? {
        switch self {
        case .invalidSize: return tr("import.error.size")
        case .invalidImage: return tr("import.error.image")
        case .noSubject: return tr("import.error.subject")
        }
    }
}

@MainActor
final class ImageImporter: ObservableObject {
    @Published var draft: NSImage?
    let placement: ImportPlacement = .blade
    @Published var error: String?
    @Published var busy = false
    @Published var revision = 0
    @Published var backgroundProcessed = false
    private var image: CGImage?
    private var operation = UUID()
    var onCommit: ((ImportPlacement) -> Void)?
    var canRemoveBackground: Bool { if #available(macOS 14, *) { return true }; return false }
    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }
    func load(_ url: URL) {
        operation = UUID(); let token = operation
        busy = true; error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try ImportedAssets.decode(url) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.operation == token else { return }
                self.busy = false
                switch result {
                case .success(let image): self.image = image; self.draft = NSImage(cgImage: image, size: .zero); self.backgroundProcessed = false
                case .failure(let error): self.error = error.localizedDescription
                }
            }
        }
    }
    func cancel() { operation = UUID(); image = nil; draft = nil; error = nil; busy = false; backgroundProcessed = false }
    func commit() {
        guard !busy, let image else { return }
        do { try ImportedAssets.save(image, as: placement); revision += 1; onCommit?(placement); cancel() }
        catch { self.error = error.localizedDescription }
    }
    func removeBackground() {
        guard #available(macOS 14, *), let image, !busy else { return }
        busy = true; error = nil; let token = UUID(); operation = token
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () throws -> CGImage in
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: image)
                try handler.perform([request])
                guard let result = request.results?.first, !result.allInstances.isEmpty else { throw ImportFailure.noSubject }
                let pixelBuffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                guard let output = CIContext().createCGImage(ciImage, from: ciImage.extent) else { throw ImportFailure.invalidImage }
                return output
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.operation == token else { return }
                self.busy = false
                switch result {
                case .success(let image): self.image = image; self.draft = NSImage(cgImage: image, size: .zero); self.backgroundProcessed = true
                case .failure(let error): self.error = error.localizedDescription
                }
            }
        }
    }
}
