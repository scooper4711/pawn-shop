import QuickLookThumbnailing
import SheetPreviewFile
import UIKit

/// A sheet's icon in Files: the picture of its first page saved in the file (docs/specs/pawn-shop R12).
final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: request.fileURL, options: .mappedIfSafe)
            guard let page = SheetPreviews(fileData: data).firstPageImage else {
                // Without a picture, the system shows the app's document icon.
                return handler(nil, CocoaError(.fileReadCorruptFile))
            }
            let image = UIImage(cgImage: page)
            let size = Self.size(of: image.size, fitting: request.maximumSize)
            handler(QLThumbnailReply(contextSize: size) {
                image.draw(in: CGRect(origin: .zero, size: size))
                return true
            }, nil)
        } catch {
            handler(nil, error)
        }
    }

    private static func size(of image: CGSize, fitting maximum: CGSize) -> CGSize {
        let scale = min(maximum.width / image.width, maximum.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}
