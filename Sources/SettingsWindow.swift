import AppKit

/// Native Settings-venster met opgeslagen voorkeuren. Opties zijn consequent
/// tussen alle vensters (gedeeld via Preferences in UserDefaults). Preview-
/// updates markeren documenten niet als gewijzigd en wijzigen geen bronbestanden.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var prefs = Preferences.load()
    private var onApply: (Preferences) -> Void = { _ in }

    private let autoCheck = NSButton(checkboxWithTitle: "Markdown-autocomplete in de broneditor", target: nil, action: nil)
    private let highlightCheck = NSButton(checkboxWithTitle: "Syntaxhighlighting voor codeblokken", target: nil, action: nil)
    private let frontMatterCheck = NSButton(checkboxWithTitle: "Front-matter-metadata tonen in statusbalk", target: nil, action: nil)
    private let statusBarCheck = NSButton(checkboxWithTitle: "Statusbalk tonen", target: nil, action: nil)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Instellingen"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Koppel een callback die bij wijziging wordt aangeroepen, zodat alle
    /// openstaande editors hun voorkeuren onmiddellijk ophalen.
    func setOnApply(_ closure: @escaping (Preferences) -> Void) { onApply = closure }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        for cb in [autoCheck, highlightCheck, frontMatterCheck, statusBarCheck] {
            cb.target = self
            cb.action = #selector(toggle)
            cb.setAccessibilityLabel(cb.title)
        }
        let stack = NSStackView(views: [autoCheck, highlightCheck, frontMatterCheck, statusBarCheck])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 8, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let ok = NSButton(title: "OK", target: self, action: #selector(applyAndClose))
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: "Annuleren", target: self, action: #selector(closeWindow))
        cancel.keyEquivalent = "\u{1b}"
        let buttonRow = NSStackView(views: [NSView(), ok, cancel])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(stack)
        content.addSubview(buttonRow)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            buttonRow.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 12),
            buttonRow.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            buttonRow.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttonRow.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
        reloadFromPrefs()
    }

    private func reloadFromPrefs() {
        autoCheck.state = prefs.autocompleteEnabled ? .on : .off
        highlightCheck.state = prefs.codeHighlightingEnabled ? .on : .off
        frontMatterCheck.state = prefs.showFrontMatter ? .on : .off
        statusBarCheck.state = prefs.showStatusBar ? .on : .off
    }

    private func readFromCheckboxes() {
        prefs.autocompleteEnabled = autoCheck.state == .on
        prefs.codeHighlightingEnabled = highlightCheck.state == .on
        prefs.showFrontMatter = frontMatterCheck.state == .on
        prefs.showStatusBar = statusBarCheck.state == .on
    }

    @objc private func toggle() {
        readFromCheckboxes()
        prefs.save()
        onApply(prefs)
    }

    @objc private func applyAndClose() {
        readFromCheckboxes()
        prefs.save()
        onApply(prefs)
        closeWindow()
    }

    @objc private func closeWindow() { window?.close() }

    override func showWindow(_ sender: Any?) {
        reloadFromPrefs()
        super.showWindow(sender)
    }
}
