import CoreGraphics
import Foundation
import QuickLookThumbnailing
import SheetPreviewFile

/// A sheet's icon in Files and in Finder: the picture of its first page saved in the file (docs/specs/pawn-shop
/// R12). The same source builds the iPhone and iPad extension (ios/PawnShop.xcodeproj) and the Mac's
/// (scripts/build-app.sh).
final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: request.fileURL, options: .mappedIfSafe)
            guard let page = SheetPreviews(fileData: data).firstPageImage else {
                // Without a picture, the system shows the app's document icon.
                return handler(nil, CocoaError(.fileReadCorruptFile))
            }
            let size = SheetPreviews.size(of: CGSize(width: page.width, height: page.height),
                                          fitting: request.maximumSize)
            handler(QLThumbnailReply(contextSize: size) { context in
                context.draw(page, in: CGRect(origin: .zero, size: size))
                return true
            }, nil)
        } catch {
            handler(nil, error)
        }
    }
}
