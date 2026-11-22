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

final class PDFWindowController: NSWindowController, NSToolbarDelegate {
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
        let toolbar = NSToolbar(identifier: "MarkeerPDFToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.delegate = self
        window.toolbar = toolbar
        window.toolbarStyle = .unified
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

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("addNote"), NSToolbarItem.Identifier("deleteNote")]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        if identifier.rawValue == "addNote" {
            item.label = "Voeg aantekening toe"; item.toolTip = "Voeg aantekening toe"
            item.image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: "Voeg aantekening toe")
            item.target = self; item.action = #selector(addTextNote)
        } else if identifier.rawValue == "deleteNote" {
            item.label = "Verwijder aantekening"; item.toolTip = "Verwijder aantekening"
            item.image = NSImage(systemSymbolName: "note.text.badge.minus", accessibilityDescription: "Verwijder aantekening")
            item.target = self; item.action = #selector(deleteSelectedNote)
        }
        return item
    }

    @objc func addTextNote() {
        guard let page = pdfView.currentPage else { return }
        let alert = NSAlert()
        alert.messageText = "Voeg aantekening toe"
        alert.informativeText = "Typ de notitie die aan deze pagina wordt toegevoegd."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 26))
        field.placeholderString = "Notitie…"
        alert.accessoryView = field
        alert.addButton(withTitle: "Toevoegen")
        alert.addButton(withTitle: "Annuleren")
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let bounds = page.bounds(for: .mediaBox)
        let noteSize = NSSize(width: 90, height: 32)
        let origin = NSPoint(x: bounds.width - noteSize.width - 16, y: bounds.height - noteSize.height - 16)
        let rect = NSRect(origin: origin, size: noteSize)
        let annotation = PDFAnnotation(bounds: rect, forType: .text, withProperties: [
            PDFAnnotationKey.contents: field.stringValue,
            PDFAnnotationKey.name: "Aantekening"
        ])
        page.addAnnotation(annotation)
        pdfDocument?.updateChangeCount(.changeDone)
        pdfView.annotationsChanged(on: page)
    }

    @objc func deleteSelectedNote() {
        guard let page = pdfView.currentPage else { return }
        guard let last = page.annotations.last else { return }
        page.removeAnnotation(last)
        pdfDocument?.updateChangeCount(.changeDone)
        pdfView.annotationsChanged(on: page)
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
            let thumb = thumbnailImage(for: page)
            let bounds = page?.bounds(for: .mediaBox) ?? .zero
            let scale = bounds.width > 0 ? 160 / bounds.width : 1
            let button = NSButton(image: thumb ?? NSImage(), target: self, action: #selector(gotoPage(_:)))
            button.tag = i
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setFrameSize(NSSize(width: 160, height: max(1, bounds.height * scale)))
            sidebarList.addArrangedSubview(button)
        }
        status.stringValue = "\(pdf.pageCount) pagina\(pdf.pageCount == 1 ? "" : "s")   ·   PDF"
    }

    func thumbnailImage(for page: PDFPage?) -> NSImage? {
        guard let page = page else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 160 / bounds.width
        let targetSize = NSSize(width: 160, height: bounds.height * scale)
        return page.thumbnail(of: targetSize, for: .mediaBox)
    }

    @objc func gotoPage(_ sender: NSButton) {
        guard let pdf = pdfDocument?.pdf, let page = pdf.page(at: sender.tag) else { return }
        pdfView.go(to: page)
    }
}
