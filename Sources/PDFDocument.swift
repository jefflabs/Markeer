import AppKit
import PDFKit

/// Highlight-annotatie opbouwen uit selectie-rects (page-gebruikerscoördinaten).
/// Zuiver en unit-testbaar: QuadPoints (8 punten per quad) bepalen het gemarkeerde
/// gebied, zodat de annotatie nooit groter wordt dan de geselecteerde tekst.
enum PDFHighlight {
    static func quadPoints(_ rects: [CGRect]) -> [CGFloat] {
        rects.flatMap { [$0.origin.x, $0.origin.y, $0.maxX, $0.origin.y, $0.maxX, $0.maxY, $0.origin.x, $0.maxY] }
    }
    static func annotation(forRects rects: [CGRect]) -> PDFAnnotation {
        // bounds = unie van de rects: renderers cullen annotaties op /Rect, dus een
        // lege bounds laat de highlight onzichtbaar. QuadPoints bepalen de exacte vorm.
        let union = rects.reduce(CGRect.null) { $0.union($1) }
        let annotation = PDFAnnotation(bounds: union, forType: .highlight, withProperties: [
            PDFAnnotationKey.color: NSColor.yellow
        ])
        annotation.setValue(quadPoints(rects), forAnnotationKey: PDFAnnotationKey.quadPoints)
        return annotation
    }
}

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

final class PromptField: NSTextField {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // return or enter
            sendAction(on: .keyDown)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class PDFWindowController: NSWindowController, NSToolbarDelegate {
    weak var pdfDocument: MarkeerPDFDocument?
    let sidebar = NSScrollView()
    let sidebarList = NSStackView()
    let pdfView = PDFView()
    let aiPanel = NSView()
    let aiPrompt = NSTextField(labelWithString: "")
    let aiSend = NSButton(title: "Vraag", target: self, action: #selector(askAI))
    let aiResponse = NSTextView()
    private var aiInput: NSTextField!
    let status = NSTextField(labelWithString: "")
    private var aiBusy = false

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
        sidebarContent.translatesAutoresizingMaskIntoConstraints = false
        sidebarContent.addSubview(sidebarList)
        notesList.orientation = .vertical
        notesList.alignment = .leading
        notesList.spacing = 4
        notesList.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        notesList.translatesAutoresizingMaskIntoConstraints = false
        sidebarContent.addSubview(notesList)
        NSLayoutConstraint.activate([
            sidebarList.topAnchor.constraint(equalTo: sidebarContent.topAnchor), sidebarList.leadingAnchor.constraint(equalTo: sidebarContent.leadingAnchor),
            sidebarList.trailingAnchor.constraint(equalTo: sidebarContent.trailingAnchor),
            notesList.topAnchor.constraint(equalTo: sidebarList.bottomAnchor, constant: 8),
            notesList.leadingAnchor.constraint(equalTo: sidebarContent.leadingAnchor),
            notesList.trailingAnchor.constraint(equalTo: sidebarContent.trailingAnchor),
            notesList.bottomAnchor.constraint(lessThanOrEqualTo: sidebarContent.bottomAnchor)
        ])
        sidebar.documentView = sidebarContent
        // Auto-Layout documentView: breedte volgt de scroll-view, hoogte volgt de
        // inhoud (thumbnails + notitie-lijst). Zonder deze koppeling blijft de
        // content 0×0 en de thumbnails/onoverzicht 0-breed.
        NSLayoutConstraint.activate([
            sidebarContent.topAnchor.constraint(equalTo: sidebar.contentView.topAnchor),
            sidebarContent.leadingAnchor.constraint(equalTo: sidebar.contentView.leadingAnchor),
            sidebarContent.trailingAnchor.constraint(equalTo: sidebar.contentView.trailingAnchor)
        ])

        // Right: AI panel (local model via Ollama)
        let aiInput = PromptField()
        aiInput.placeholderString = "Vraag over dit document…"
        aiInput.target = self
        aiInput.action = #selector(askAI)
        aiInput.translatesAutoresizingMaskIntoConstraints = false
        aiSend.translatesAutoresizingMaskIntoConstraints = false
        aiSend.target = self
        aiSend.action = #selector(askAI)
        let aiResponseScroll = NSScrollView()
        aiResponseScroll.hasVerticalScroller = true
        aiResponseScroll.borderType = .noBorder
        aiResponseScroll.translatesAutoresizingMaskIntoConstraints = false
        aiResponse.isEditable = false
        aiResponse.isSelectable = true
        aiResponse.drawsBackground = false
        aiResponse.textContainerInset = NSSize(width: 0, height: 8)
        aiResponseScroll.documentView = aiResponse
        aiPanel.addSubview(aiInput); aiPanel.addSubview(aiSend); aiPanel.addSubview(aiResponseScroll)
        NSLayoutConstraint.activate([
            aiInput.topAnchor.constraint(equalTo: aiPanel.topAnchor, constant: 12),
            aiInput.leadingAnchor.constraint(equalTo: aiPanel.leadingAnchor, constant: 12),
            aiInput.trailingAnchor.constraint(equalTo: aiSend.leadingAnchor, constant: -6),
            aiSend.topAnchor.constraint(equalTo: aiPanel.topAnchor, constant: 10),
            aiSend.trailingAnchor.constraint(equalTo: aiPanel.trailingAnchor, constant: -12),
            aiResponseScroll.topAnchor.constraint(equalTo: aiInput.bottomAnchor, constant: 12),
            aiResponseScroll.leadingAnchor.constraint(equalTo: aiPanel.leadingAnchor, constant: 12),
            aiResponseScroll.trailingAnchor.constraint(equalTo: aiPanel.trailingAnchor, constant: -12),
            aiResponseScroll.bottomAnchor.constraint(equalTo: aiPanel.bottomAnchor, constant: -12)
        ])
        self.aiInput = aiInput

        // Klassieke split-view: de paneel-frames worden door de split-view zelf
        // gestuurd. De panelen moeten daarom géén Auto-Layout-views zijn
        // (translatesAutoresizingMaskIntoConstraints = true), anders rekent de
        // constraint-engine hun frames uit als 0×0 (geen width/height-constraints)
        // en worden de panelen onzichtbaar.
        split.addArrangedSubview(sidebar); split.addArrangedSubview(pdfView); split.addArrangedSubview(aiPanel)
        // Eerst de constraints uitrekenen zodat de split-view zijn echte frame heeft;
        // anders worden de divider-posities op een 0×0-frame geklemd en blijft de
        // sidebar (thumbnails en notities) onzichtbaar (0 breed).
        root.layoutSubtreeIfNeeded()
        split.setPosition(200, ofDividerAt: 0)
        split.setPosition(640, ofDividerAt: 1)
        pdfView.document = pdfDocument?.pdf
        reloadFromDocument()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("addNote"), NSToolbarItem.Identifier("deleteNote"),
         NSToolbarItem.Identifier("highlight")]
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
        } else if identifier.rawValue == "highlight" {
            item.label = "Markeer"; item.toolTip = "Markeer geselecteerde tekst"
            item.image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "Markeer tekst")
            item.target = self; item.action = #selector(addHighlight)
        }
        return item
    }

    /// Maakt een highlight-annotatie voor de geselecteerde tekst op deze pagina.
    /// De selectie wordt per regel omgezet in page-space rects (QuadPoints), zodat
    /// alleen de geselecteerde tekst gemarkeerd wordt. Zonder selectie (of zonder
    /// dektekt op de pagina) is het resultaat nil: de toolbar-knop is dan een no-op.
    func highlight(selection: PDFSelection?, on page: PDFPage) -> PDFAnnotation? {
        guard let selection, selection.pages.contains(page) else { return nil }
        var rects: [CGRect] = []
        for line in selection.selectionsByLine() where line.pages.contains(page) {
            let rect = line.bounds(for: page)
            if !rect.isNull, !rect.isEmpty { rects.append(rect) }
        }
        guard !rects.isEmpty else { return nil }
        return PDFHighlight.annotation(forRects: rects)
    }

    @objc func addHighlight() {
        guard let selection = pdfView.currentSelection else { return }
        var added = false
        for page in selection.pages {
            guard let annotation = highlight(selection: selection, on: page) else { continue }
            page.addAnnotation(annotation)
            pdfView.annotationsChanged(on: page)
            added = true
        }
        if added { pdfDocument?.updateChangeCount(.changeDone) }
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
        refreshNotesList()
    }

    @objc func deleteSelectedNote() {
        guard let page = pdfView.currentPage else { return }
        // Alleen Text-annotaties zijn notities: PDFKit houdt per notitie ook een
        // gepaarde Popup-annotatie bij, en highlights mogen niet per ongeluk weg.
        guard let last = page.annotations.last(where: { $0.type == "Text" }) else { return }
        page.removeAnnotation(last)
        pdfDocument?.updateChangeCount(.changeDone)
        pdfView.annotationsChanged(on: page)
        refreshNotesList()
    }

    // Notitie-lijst in de sidebar (onder de thumbnails)
    private let notesList = NSStackView()
    private let notesTitle = NSTextField(labelWithString: "Aantekeningen")

    func reloadFromDocument() {
        guard let pdf = pdfDocument?.pdf else {
            sidebarList.arrangedSubviews.forEach { $0.removeFromSuperview() }
            notesList.arrangedSubviews.forEach { $0.removeFromSuperview() }
            pdfView.document = nil
            status.stringValue = ""
            return
        }
        pdfView.document = pdf
        sidebarList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // Thumbnails
        for i in 0..<pdf.pageCount {
            let page = pdf.page(at: i)
            let thumb = thumbnailImage(for: page)
            let bounds = page?.bounds(for: .mediaBox) ?? .zero
            let scale = bounds.width > 0 ? 160 / bounds.width : 1
            let button = NSButton(image: thumb ?? NSImage(), target: self, action: #selector(gotoPage(_:)))
            button.tag = i
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            let h = max(1, bounds.height * scale)
            button.widthAnchor.constraint(equalToConstant: 160).isActive = true
            button.heightAnchor.constraint(equalToConstant: h).isActive = true
            sidebarList.addArrangedSubview(button)
        }
        refreshNotesList()
        status.stringValue = "\(pdf.pageCount) pagina\(pdf.pageCount == 1 ? "" : "s")   ·   PDF   ·   v\(appVersion())"
    }

    /// Bouwt de notitie-lijst in de sidebar opnieuw op (alle Text-annotaties per
    /// pagina). Los van reloadFromDocument zodat de lijst direct bijwerkt na
    /// toevoegen/verwijderen van een notitie zonder het PDF-weergave-venster te resetten.
    func refreshNotesList() {
        notesList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        notesTitle.font = .boldSystemFont(ofSize: 11)
        notesTitle.textColor = .secondaryLabelColor
        notesList.addArrangedSubview(notesTitle)
        guard let pdf = pdfDocument?.pdf else { return }
        var hasNotes = false
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            for annotation in page.annotations where annotation.type == "Text" {
                hasNotes = true
                let contents = (annotation.value(forAnnotationKey: PDFAnnotationKey.contents) as? String) ?? ""
                let noteLabel = NSTextField(labelWithString: "P.\(i+1): \(contents.prefix(60))")
                noteLabel.font = .systemFont(ofSize: 10)
                noteLabel.lineBreakMode = .byTruncatingTail
                noteLabel.translatesAutoresizingMaskIntoConstraints = false
                noteLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
                // Klik → ga naar pagina
                let wrapper = NSView()
                wrapper.identifier = NSUserInterfaceItemIdentifier("note-\(i)")
                wrapper.addSubview(noteLabel)
                noteLabel.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    noteLabel.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    noteLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                    noteLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                    noteLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
                ])
                wrapper.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(navigateToNotePage(_:))))
                notesList.addArrangedSubview(wrapper)
            }
        }
        if !hasNotes {
            let emptyLabel = NSTextField(labelWithString: "(geen notities)")
            emptyLabel.font = .systemFont(ofSize: 10)
            emptyLabel.textColor = .tertiaryLabelColor
            notesList.addArrangedSubview(emptyLabel)
        }
    }

    @objc func navigateToNotePage(_ sender: NSClickGestureRecognizer) {
        guard let view = sender.view,
              let idStr = view.identifier?.rawValue,
              let pageIdx = Int(idStr.replacingOccurrences(of: "note-", with: "")),
              let pdf = pdfDocument?.pdf, let page = pdf.page(at: pageIdx) else { return }
        pdfView.go(to: page)
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

    @objc func askAI() {
        let prompt = aiInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aiBusy, !prompt.isEmpty else { return }
        let currentText = pdfView.currentPage?.string ?? ""
        let context = (currentText.isEmpty ? (pdfDocument?.pdf?.string ?? "") : currentText).prefix(12000)
        aiInput.stringValue = ""
        aiBusy = true
        aiSend.isEnabled = false
        appendAIText("\n\n> \(prompt)\n\n_Laden…_")
        AskAI.shared.ask(prompt: prompt, context: String(context)) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.aiBusy = false
                self.aiSend.isEnabled = true
                switch result {
                case .success(let text): self.appendAIText(text)
                case .failure(let error): self.appendAIText("_(fout: \(error.localizedDescription))_")
                }
            }
        }
    }

    private func appendAIText(_ text: String) {
        aiResponse.textStorage?.append(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12)]))
        aiResponse.scrollToEndOfDocument(nil)
    }
}
