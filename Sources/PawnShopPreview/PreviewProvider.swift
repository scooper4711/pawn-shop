import QuickLook
import SheetPreviewFile
import UniformTypeIdentifiers

/// A sheet in Quick Look: the pictures of its pages saved in the file (docs/specs/pawn-shop R12).
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL, options: .mappedIfSafe)
        let previews = SheetPreviews(fileData: data)
        let pdf = previews.pdfData()
        guard !pdf.isEmpty, let page = previews.firstPageImage else { throw CocoaError(.fileReadCorruptFile) }
        let size = CGSize(width: page.width, height: page.height)
        return QLPreviewReply(dataOfContentType: .pdf, contentSize: size) { _ in pdf }
    }
}
