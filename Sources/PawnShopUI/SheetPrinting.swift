import PawnShopCore
import SwiftUI

#if os(macOS)
import AppKit
import PDFKit

/// Page Setup and printing on the Mac.
@MainActor
enum SheetOutput {
    /// Shows Page Setup for the sheet's paper and stores the result in the sheet.
    static func runPageSetup(for sheet: inout PawnSheet) {
        let info = printInfo(for: sheet.settings.paper)
        guard NSPageLayout().runModal(with: info) == NSApplication.ModalResponse.OK.rawValue else { return }
        let imageable = info.imageablePageBounds
        guard info.paperSize.width > 0, imageable.width > 0 else { return }
        sheet.settings.paper = PaperSetup(paperSize: info.paperSize, imageableRect: imageable)
    }

    /// Prints exactly as laid out: no scaling, rotation or extra margins.
    static func print(_ data: Data, title: String, paper: PaperSetup) {
        guard let document = PDFDocument(data: data) else { return }
        let info = printInfo(for: paper)
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        guard let operation = document.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false)
        else { return }
        operation.jobTitle = title
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        // A sheet still attached to the window would take the print panel with it, so use the window itself.
        if let window = NSApp.keyWindow.map({ $0.sheetParent ?? $0 }) {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    private static func printInfo(for paper: PaperSetup) -> NSPrintInfo {
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.paperSize = paper.paperSize
        return info
    }
}

/// The inspector's paper: its size, and Page Setup to change it.
struct PaperControl: View {
    @Binding var sheet: PawnSheet

    var body: some View {
        Button("Page Setup…") { SheetOutput.runPageSetup(for: &sheet) }
    }
}

#else
import UIKit

/// Printing on the iPad.
@MainActor
enum SheetOutput {
    /// Prints every page at 100%, asking the printer for the sheet's paper.
    static func print(_ data: Data, title: String, paper: PaperSetup) {
        ActualSizePrinter.print(data, title: title, paperSize: paper.paperSize)
    }
}

/// The inspector's paper. The iPad has no Page Setup, so the sizes are listed, each with a ¼ in margin.
struct PaperControl: View {
    @Binding var sheet: PawnSheet

    var body: some View {
        Menu("Paper") {
            Picker("Paper", selection: $sheet.settings.paper.named) {
                ForEach(NamedPaper.allCases) { Text($0.title).tag(Optional($0)) }
            }
        }
        .fixedSize()
    }
}

/// Prints a PDF on the iPad exactly as laid out. Handing the PDF to the print panel as a printing item would scale
/// each page to the printer's printable area; this draws every page at the paper's origin at 100% instead, and
/// asks the printer for the paper the sheet was laid out on.
@MainActor
enum ActualSizePrinter {
    static func print(_ data: Data, title: String, paperSize: CGSize) {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider) else {
            return
        }
        let info = UIPrintInfo.printInfo()
        info.jobName = title
        info.outputType = .general
        info.orientation = .portrait

        let controller = UIPrintInteractionController.shared
        let delegate = PaperChooser(paperSize: paperSize)
        controller.printInfo = info
        controller.printPageRenderer = ActualSizeRenderer(document: document)
        controller.delegate = delegate
        controller.present(animated: true) { _, _, _ in
            // The controller holds its delegate weakly; this keeps it until the print panel is done.
            withExtendedLifetime(delegate) {}
        }
    }
}

/// Asks the printer for the paper the sheet was laid out on, or the closest it has.
private final class PaperChooser: NSObject, UIPrintInteractionControllerDelegate {
    let paperSize: CGSize

    init(paperSize: CGSize) {
        self.paperSize = paperSize
    }

    func printInteractionController(_ controller: UIPrintInteractionController,
                                    choosePaper paperList: [UIPrintPaper]) -> UIPrintPaper {
        UIPrintPaper.bestPaper(forPageSize: paperSize, withPapersFrom: paperList)
    }
}

/// Draws each page of the PDF at the paper's top-left corner, one PDF point to one printed point.
private final class ActualSizeRenderer: UIPrintPageRenderer {
    private let document: CGPDFDocument

    init(document: CGPDFDocument) {
        self.document = document
    }

    override var numberOfPages: Int { document.numberOfPages }

    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        guard let page = document.page(at: pageIndex + 1), let context = UIGraphicsGetCurrentContext() else { return }
        let box = page.getBoxRect(.mediaBox)
        context.saveGState()
        // The context is in paper coordinates with the origin at the top left; PDF pages have theirs at the
        // bottom left.
        context.translateBy(x: paperRect.minX, y: paperRect.minY + box.height)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        context.restoreGState()
    }
}
#endif
