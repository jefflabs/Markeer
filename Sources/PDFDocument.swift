import AppKit
import PDFKit

@objc(MarkeerPDFDocument)
final class MarkeerPDFDocument: NSDocument {
    var pdf: PDFKit.PDFDocument? { didSet { documentChanged() } }
    override class var autosavesInPlace: Bool { true }
    override var autosavingFileType: String? { "public.pdf" }
    override func makeWindowControllers() {
        let controller = PDFWindowController(document: self)
        addWindowController(controller)
    }
    override func data(ofType typeName: String) throws -> Data {
        guard let pdf = pdf else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        return pdf.dataRepresentation() ?? Data()
    }
    override func read(from data: Data, ofType typeName: String) throws {
        guard let pdf = PDFKit.PDFDocument(data: data) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        self.pdf = pdf
        for window in windowControllers { (window as? PDFWindowController)?.reloadFromDocument() }
    }
    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? { "pdf" }
    func documentChanged() {
        for window in windowControllers { (window as? PDFWindowController)?.reloadFromDocument() }
    }
}

final class PDFWindowController: NSWindowController {
    weak var pdfDocument: MarkeerPDFDocument?
    let sidebar = NSScrollView()
    let sidebarList = NSStackView()
    let pdfView = PDFView()
    let aiPlaceholder = NSTextField(labelWithString: "")
    let status = NSTextField(labelWithString: "")

    init(document: MarkeerPDFDocument) {
        pdfDocument = document
        let window = NSWindow(contentRect: NSRect(x:0,y:0,width:1120,height:780),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.minSize = NSSize(width:640,height:420)
        window.title = "Markeer"
        window.setFrameAutosaveName("MarkeerPDFEditor")
        window.center()
        window.tabbingMode = .preferred
        super.init(window: window)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setup() {
        guard let window else { return }
        let root = NSView(); window.contentView = root
        let split = NSSplitView(); split.isVertical = true; split.dividerStyle = .thin
        root.addSubview(split)
        split.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 11, weight: .medium)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(status)
        NSLayoutConstraint.activate([
            split.topAnchor.constraint(equalTo: root.topAnchor), split.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: root.trailingAnchor), split.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -9),
            status.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), status.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -9),
            status.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16)
        ])

        // Left sidebar: pages
        sidebar.hasVerticalScroller = true; sidebar.borderType = .noBorder
        sidebarList.orientation = .vertical; sidebarList.alignment = .centerX
        sidebarList.spacing = 12; sidebarList.edgeInsets = NSEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        sidebarList.translatesAutoresizingMaskIntoConstraints = false
        let sidebarContent = NSView()
        sidebarContent.addSubview(sidebarList)
        NSLayoutConstraint.activate([
            sidebarList.topAnchor.constraint(equalTo: sidebarContent.topAnchor), sidebarList.leadingAnchor.constraint(equalTo: sidebarContent.leadingAnchor),
            sidebarList.trailingAnchor.constraint(equalTo: sidebarContent.trailingAnchor), sidebarList.bottomAnchor.constraint(equalTo: sidebarContent.bottomAnchor)
        ])
        sidebar.documentView = sidebarContent
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        // Center: PDF view
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        // Right: AI placeholder (later)
        aiPlaceholder.isEditable = false; aiPlaceholder.isSelectable = false
        aiPlaceholder.alignment = .center
        aiPlaceholder.textColor = .secondaryLabelColor
        aiPlaceholder.font = .systemFont(ofSize: 13)
        aiPlaceholder.stringValue = "Ask AI — later"
        aiPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        split.addArrangedSubview(sidebar); split.addArrangedSubview(pdfView); split.addArrangedSubview(aiPlaceholder)
        split.setPosition(200, ofDividerAt: 0)
        split.setPosition(640, ofDividerAt: 1)
        pdfView.document = pdfDocument?.pdf
        reloadFromDocument()
    }

    func reloadFromDocument() {
        guard let pdf = pdfDocument?.pdf else {
            sidebarList.arrangedSubviews.forEach { $0.removeFromSuperview() }
            pdfView.document = nil
            status.stringValue = ""
            return
        }
        pdfView.document = pdf
        sidebarList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for i in 0..<pdf.pageCount {
            let page = pdf.page(at: i)
            let button = NSButton(image: thumbnailImage(for: page) ?? NSImage(), target: self, action: #selector(gotoPage(_:)))
            button.tag = i
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setFrameSize(NSSize(width: 160, height: 210))
            sidebarList.addArrangedSubview(button)
        }
        status.stringValue = "\(pdf.pageCount) pagina\(pdf.pageCount == 1 ? "" : "s")   ·   PDF"
    }

    func thumbnailImage(for page: PDFPage?) -> NSImage? {
        guard let page = page else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 0.45
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        if let cgContext = NSGraphicsContext.current?.cgContext {
            cgContext.saveGState()
            cgContext.scaleBy(x: scale, y: scale)
            cgContext.translateBy(x: 0, y: bounds.height)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()
        }
        image.unlockFocus()
        return image
    }

    @objc func gotoPage(_ sender: NSButton) {
        guard let pdf = pdfDocument?.pdf, let page = pdf.page(at: sender.tag) else { return }
        pdfView.go(to: page)
    }
}
