import Foundation

struct RenderBlock: Codable {
    let id: Int
    let html: String
    let source: String
}
struct FrontMatter: Codable {
    let source: String
    let entries: [(String, String)]
    init(source: String, entries: [(String, String)]) { self.source = source; self.entries = entries }
    // Alleen de exacte brontekst wordt overgebracht; entries worden lokaal uit bron gegenereerd
    // zodat JS-side nooit zelf moet parsen en roundtrip byte-exact blijft.
    private struct Box: Codable { let source: String }
    init(from decoder: Decoder) throws {
        let box = try Box(from: decoder)
        self.source = box.source
        self.entries = Markdown.parseYAMLEntriesFromString(box.source)
    }
    func encode(to encoder: Encoder) throws {
        try Box(source: source).encode(to: encoder)
    }
}
struct RenderedMarkdown: Codable {
    let frontMatter: FrontMatter?
    let blocks: [RenderBlock]
    let references: String
}

/// Versie-hulpfunctie: leest de bundle-versie (ShortVersionString + build) uit Info.plist.
public func appVersion() -> String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? ""
    return build.isEmpty ? short : "\(short) (\(build))"
}

enum Markdown {
    /// Herkent uitsluitend een YAML-front-matterblok op het documentbegin (Jekyll-conventie).
    /// Een lege eerste regel, voorafgaande ruimte of een afsluiting anders dan exact "---"
    /// maken het blok niet-herkenbaar; de body wordt dan integraal gerenderd.
    /// Gemaakt als (matter, body) zodat de UI het blok exact kan hergebruiken (roundtrip).
    static func extractFrontMatter(_ source: String) -> (matter: FrontMatter, body: String)? {
        let lines = source.components(separatedBy: "\n")
        guard lines.first == "---" else { return nil }
        guard let closeIdx = lines.dropFirst().firstIndex(of: "---") else { return nil }
        let matterLines = Array(lines[0..<closeIdx+1])
        let bodyLines = Array(lines[(closeIdx+1)...])
        let matterSource = matterLines.joined(separator: "\n")
        let body = bodyLines.joined(separator: "\n")
        let entries = parseYAMLEntries(matterLines.dropFirst().dropLast())
        return (FrontMatter(source: matterSource, entries: entries), body)
    }
    static func parseYAMLEntriesFromString(_ block: String) -> [(String, String)] {
        let lines = block.components(separatedBy: "\n")
        // Verwacht de eerste en laatste regel zijn "---"; strip ze zodat parseYAMLEntries(
        // [String]) de werkelijke key/value-regels ziet.
        guard lines.first == "---", let last = lines.last, last == "---" else { return [] }
        return parseYAMLEntries(Array(lines.dropFirst().dropLast()))
    }
    /// Platte key: value-mapping lezen uit front-matterregels (Jekyll-standaard).
    /// Ondersteunt inline scalar, block scalar (|, >), inline lijst [a, b] en eenvoudige
    /// geneste lijsten (regels die beginnen met "- ") onder een lege key.
    static func parseYAMLEntries(_ lines: [String]) -> [(String, String)] {
        var entries: [(String, String)] = []
        var currentKey: String? = nil
        var buffer: [String] = []
        var inBlock = false
        func flush() {
            guard let k = currentKey else { return }
            let value = buffer.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            entries.append((k, value))
            currentKey = nil; buffer = []; inBlock = false
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inBlock {
                if line.hasPrefix(" ") || line.hasPrefix("\t") || trimmed.isEmpty {
                    buffer.append(trimmed)
                    continue
                } else { flush() }
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let colon = trimmed.firstIndex(of: ":") {
                let k = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
                let v = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                flush()
                currentKey = k
                if ["|","|+","|-",">",">+",">-"].contains(v) { inBlock = true; buffer = [] }
                else { buffer = [v] }
                continue
            }
            // lijst-item onder huidige key
            if trimmed.hasPrefix("- "), currentKey != nil {
                buffer.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            }
        }
        flush()
        return entries
    }

    static func render(_ source: String) -> RenderedMarkdown {
        let split = extractFrontMatter(source)
        let matter = split?.matter
        // Wiskunde: zet math-delimiters om naar KaTeX-placeholder spans (code-aware).
        // De editor converteert de spans weer terug naar de oorspronkelijke notatie,
        // dus de math-bron blijft behouden bij rich edits.
        let inlineDollar = Preferences.load().inlineDollarMath
        // Wiskunde eerst (maakt placeholders), daarna highlight ==...==.
        let renderSource = applyMarkHighlight(applyMath(split?.body ?? source, inlineDollar: inlineDollar))
        cmark_gfm_core_extensions_ensure_registered()
        let options = Int32(CMARK_OPT_DEFAULT | CMARK_OPT_FOOTNOTES)
        guard let parser = cmark_parser_new(options) else { return .init(frontMatter: matter, blocks: [], references: "") }
        defer { cmark_parser_free(parser) }
        for name in ["table", "strikethrough", "autolink", "tasklist", "tagfilter"] {
            name.withCString { if let ext = cmark_find_syntax_extension($0) { cmark_parser_attach_syntax_extension(parser, ext) } }
        }
        renderSource.withCString { cmark_parser_feed(parser, $0, renderSource.utf8.count) }
        guard let root = cmark_parser_finish(parser) else { return .init(frontMatter: matter, blocks: [], references: "") }
        defer { cmark_node_free(root) }
        preserveInlineHTML(root)
        let lines = renderSource.components(separatedBy: "\n")
        var covered = Set<Int>()
        var blocks: [RenderBlock] = []
        var node = cmark_node_first_child(root)
        while let current = node {
            let start = max(0, Int(cmark_node_get_start_line(current)) - 1)
            let end = min(lines.count - 1, Int(cmark_node_get_end_line(current)) - 1)
            let original = start <= end ? lines[start...end].joined(separator: "\n") : ""
            if start <= end { covered.formUnion(start...end) }
            var html = ""
            if cmark_node_get_type(current) == CMARK_NODE_HTML_BLOCK {
                html = "<pre class=\"raw-html\" contenteditable=\"false\">" + escape(original) + "</pre>"
            } else if let rendered = cmark_render_html(current, options, cmark_parser_get_syntax_extensions(parser)) {
                html = String(cString: rendered)
                free(rendered)
            }
            blocks.append(.init(id: blocks.count, html: html, source: original))
            node = cmark_node_next(current)
        }
        let references = lines.enumerated().filter { !covered.contains($0.offset) && !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }.map(\.element).joined(separator: "\n")
        return .init(frontMatter: matter, blocks: blocks, references: references)
    }
    static func preserveInlineHTML(_ node: OpaquePointer) {
        var child = cmark_node_first_child(node)
        while let current = child {
            child = cmark_node_next(current)
            // Laat math-placeholders onaangetast: de editor converteert deze terug
            // naar de oorspronkelijke notatie (katex-src), dus geen raw-HTML-protectie.
            let isMath = cmark_node_get_type(current) == CMARK_NODE_HTML_INLINE &&
                { () -> Bool in
                    guard let lit = cmark_node_get_literal(current) else { return false }
                    return String(cString: lit).contains("data-math-placeholder")
                }()
            if cmark_node_get_type(current) == CMARK_NODE_HTML_INLINE && !isMath,
               let literal = cmark_node_get_literal(current),
               let replacement = cmark_node_new(CMARK_NODE_CUSTOM_INLINE) {
                let safe = "<code data-raw-inline=\"true\">" + escape(String(cString: literal)) + "</code>"
                safe.withCString { _ = cmark_node_set_on_enter(replacement, $0) }
                _ = cmark_node_set_on_exit(replacement, "")
                if cmark_node_replace(current, replacement) != 0 { cmark_node_free(current) }
                else { cmark_node_free(replacement) }
            } else { preserveInlineHTML(current) }
        }
    }
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// `==tekst==` → `<mark>tekst</mark>` (GitHub-stijl highlight), behalve binnen
    /// gefenced codeblokken of inline-code. De bron blijft `==tekst==`; de editor
    /// converteert `<mark>` weer terug (zie editor.js 'mark'-regel), dus roundtrip is exact.
    static func applyMarkHighlight(_ source: String) -> String {
        // Alleen activeren als de bron geen <mark> bevat; zo is de roundtrip
        // stabiel: de eerste render maakt van ==..== <mark>, en de volgende
        // renders (na editor-edit) hebben <mark> en doen niets meer.
        if source.contains("<mark>") { return source }
        var inFence = false
        var fenceMarker = ""
        var lines = source.components(separatedBy: "\n")
        for i in lines.indices {
            var line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                // Fence-toggle.
                let marker = String(trimmed.prefix(3))
                if !inFence { inFence = true; fenceMarker = marker }
                else if trimmed.hasPrefix(fenceMarker) { inFence = false; fenceMarker = "" }
                lines[i] = line
                continue
            }
            if inFence { continue }
            // Buiten code: vervang ==...== buiten inline-code-backticks.
            lines[i] = replaceMarkOutsideCode(line)
        }
        return lines.joined(separator: "\n")
    }

    static func replaceMarkOutsideCode(_ line: String) -> String {
        // Split op inline-code (`...`) zodat we die niet aanraken.
        let segments = line.components(separatedBy: "`")
        let transformed = segments.enumerated().map { idx, seg -> String in
            // Evene segmenten = niet-code (0,2,4,…), oneven = code.
            if idx % 2 == 1 { return seg }
            return seg.replacingOccurrences(of: #"==([^=]+)="#, with: "<mark>$1</mark>", options: .regularExpression)
        }
        return transformed.joined(separator: "`")
    }

    /// Zet math-delimiters om naar KaTeX-placeholder spans zodat cmark-gfm de
    /// wiskunde niet als gewone tekst/HTML breekt. Onbekende of onvolledige
    /// formules blijven gewoon tekst (geen crash). Codeblokken en inline-code
    /// worden beschermd. De editor (editor.js) converteert de spans terug naar
    /// de oorspronkelijke notatie, zodat de math-bron behouden blijft.
    static func applyMath(_ source: String, inlineDollar: Bool) -> String {
        var inFence = false
        var fenceMarker = ""
        var inDisplayMath = false
        var mathLines: [String] = []
        var mathIndent = ""
        var out: [String] = []
        var lines = source.components(separatedBy: "\n")
        var i = 0
        func flushMath() {
            let formula = mathLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(mathIndent + mathSpan(formula, display: true))
            mathLines = []
        }
        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            // Fence-detectie (alleen buiten display-math).
            if !inDisplayMath && (trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")) {
                let marker = String(trimmed.prefix(3))
                if !inFence { inFence = true; fenceMarker = marker }
                else if trimmed.hasPrefix(fenceMarker) { inFence = false; fenceMarker = "" }
                out.append(raw)
                i += 1
                continue
            }
            if inFence { out.append(raw); i += 1; continue }
            // Buiten code.
            if inDisplayMath {
                if trimmed.hasSuffix("$$") || trimmed == "$$" {
                    // Sluitende regel: alles vóór het laatste $$ is formule-inhoud.
                    let closePre = String(trimmed.dropLast(2))
                    if !closePre.trimmingCharacters(in: .whitespaces).isEmpty { mathLines.append(closePre) }
                    flushMath()
                    inDisplayMath = false
                } else {
                    mathLines.append(raw)
                }
                i += 1
                continue
            }
            // Openen we display-math? ($$ op een niet-code regel, mogelijk met inhoud)
            let isCodeLine = inInlineCode(raw)
            if !isCodeLine {
                if trimmed.hasPrefix("$$") {
                    // Zelfde-regel sluiting? $$...$$
                    if trimmed.count >= 4 && trimmed.hasSuffix("$$") {
                        let formula = String(trimmed.dropFirst(2).dropLast(2))
                        out.append(raw.replacingOccurrences(of: trimmed, with: mathSpan(formula, display: true)))
                        i += 1
                        continue
                    }
                    // Multi-line: openen.
                    inDisplayMath = true
                    mathIndent = String(raw.prefix(while: { $0 == " " || $0 == "\t" }))
                    let after = String(trimmed.dropFirst(2))
                    if !after.trimmingCharacters(in: .whitespaces).isEmpty { mathLines.append(after) }
                    i += 1
                    continue
                }
            }
            out.append(replaceMathOutsideCode(raw, inlineDollar: inlineDollar))
            i += 1
        }
        if inDisplayMath { flushMath() } // onvoltooid: weeg de bron op als math (geen crash)
        return out.joined(separator: "\n")
    }

    /// True als de regel zich in een inline-code-segment bevindt (oneven aantal backticks).
    private static func inInlineCode(_ line: String) -> Bool {
        line.filter { $0 == "`" }.count % 2 == 1
    }

    static func replaceMathOutsideCode(_ line: String, inlineDollar: Bool) -> String {
        // Split op inline-code zodat we die niet aanraken.
        let segments = line.components(separatedBy: "`")
        let transformed = segments.enumerated().map { idx, seg -> String in
            if idx % 2 == 1 { return seg } // code: onaangetast
            var out = seg
            // $$...$$ display-math (op één regel).
            out = out.replacingOccurrences(of: #"\$\$(.+?)\$\$"#, with: mathSpan("$1", display: true), options: .regularExpression)
            // \.\[...\] display-math.
            out = out.replacingOccurrences(of: #"\\\[([^\]]+?)\\\]"#, with: mathSpan("$1", display: true), options: .regularExpression)
            // \.\(...\) inline-math.
            out = out.replacingOccurrences(of: #"\\\(([^)]+?)\\\)"#, with: mathSpan("$1", display: false), options: .regularExpression)
            if inlineDollar {
                // $...$ inline-math; vereist dat er vóór de opening en na de
                // sluiting geen cijfer/letter direct staat, zodat $5 of a$b niet
                // wordt aangepakt. Ook geen lege $ $.
                out = out.replacingOccurrences(of: #"(?<![\\$\\w])\$([^$\\n]+?)\$(?![\\w$])"#, with: mathSpan("$1", display: false), options: .regularExpression)
            }
            return out
        }
        return transformed.joined(separator: "`")
    }

    /// Plaatshouderspan die de editor terugherkent. `katex-src` bevaat de
        /// Plaatshouders als veilige plain-text sentinel: cmark-gfm rendert dit gewoon
    /// als tekst (geen HTML, dus veilig), de editor.js herkent het en rendert KaTeX,
    /// en bij serialize gaat het terug naar de oorspronkelijke notatie. De formule
    /// zit base64-encoded zodat speciale tekens niet breken.
    static func mathSpan(_ formula: String, display: Bool) -> String {
        let b64 = Data(formula.utf8).base64EncodedString()
        let marker = display ? "⌘M1" : "⌘M0"  // M1=display, M0=inline
        return "\(marker)\(b64)\(marker)"
    }
}

struct NumberedListEdit {
    let range: NSRange
    let text: String
}

enum MarkdownEditing {
    @discardableResult
    static func numberedList(in text: String, selection: NSRange) -> NumberedListEdit {
        let source = text as NSString
        let location = min(selection.location, source.length)
        var length = min(selection.length, source.length - location)
        // A selection ending at the next line's start must leave that line alone.
        if length > 0 && source.character(at: location + length - 1) == 10 { length -= 1 }
        let range = source.lineRange(for: NSRange(location: location, length: length))
        let block = source.substring(with: range)
        let trailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if trailingNewline { lines.removeLast() }
        let prefix = try! NSRegularExpression(pattern: "^([ \t]*)(?:[-+*][ \t]+|[0-9]+[.)][ \t]+)")
        var number = 1
        let numbered = lines.map { line -> String in
            if line.trimmingCharacters(in: .whitespaces).isEmpty && lines.count > 1 { return line }
            let clean = prefix.stringByReplacingMatches(in: line, range: NSRange(location: 0, length: (line as NSString).length), withTemplate: "$1")
            let indent = String(clean.prefix(while: { $0 == " " || $0 == "\t" }))
            defer { number += 1 }
            return indent + "\(number). " + clean.dropFirst(indent.count)
        }.joined(separator: "\n")
        return .init(range: range, text: numbered + (trailingNewline ? "\n" : ""))
    }

    // MARK: - Autocomplete (Markdown-delimiters, links, lijstcontinuatie)
    //
    // Deze pure functies geven terug welke invoer bij een gegeven caret/punt
    // moet worden toegevoegd. De editor (NSTextView) past de uitkomst toe;
    // zo blijven selectie, caretpositie, Unicode en IME.testbaar zonder UI.

    /// Resultaat van een autocomplete-voorstel.
    struct Completion {
        /// Tekst die wordt ingevoegd (of vervangen binnen `replaceRange`).
        let insert: String
        /// Optioneel: bestaand bereik dat door `insert` wordt vervangen.
        var replaceRange: NSRange? = nil
        /// Caret-offset RELATIEF aan het begin van `insert` na invoeging.
        let caretOffset: Int
    }

    static let newlineCharacter: Character = "\n"

    /// Lijstcontinuatie: bij Enter op een niet-lege lijstregel voorspelt de
    /// volgende regel dezelfde marker (zelfde indent en stijl). Een lege
    /// lijstregel ("- " zonder inhoud) levert géén nieuwe marker op — dat
    /// stopt de lijst (standaard gedrag).
    static func listContinuation(beforeCaret text: String, caret: Int) -> Completion? {
        let src = text as NSString
        let caret = min(caret, src.length)
        // Het getypte Enter is het teken op positie caret-1; de inhoudsregel eindigt daar.
        guard caret > 0, src.character(at: caret - 1) == 10 else { return nil }
        let lineRange = src.lineRange(for: NSRange(location: caret - 1, length: 0))
        // contentLine = de regel vóór het getypte \n (dus zonder dat \n).
        let contentLine = src.substring(with: NSRange(location: lineRange.location, length: lineRange.length - 1))
        guard !contentLine.isEmpty else { return nil }
        guard let m = contentLine.range(of: #"^([ \t]*)([-+*][ \t]+|[0-9]+[.)][ \t]+)"#, options: .regularExpression) else { return nil }
        let whole = String(contentLine[m])
        let indent = whole.prefix(while: { $0 == " " || $0 == "\t" })
        let marker = String(whole.dropFirst(indent.count))
        // Een lege lijst-item (alleen marker + eventueel witruimte, geen inhoud) stopt de lijst.
        let afterMarker = contentLine.dropFirst(whole.count)
        guard !afterMarker.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return Completion(insert: String(indent) + marker, caretOffset: (indent + marker).count)
    }

    /// Delimiter-aanvulling: als de gebruiker een delimiter-tekentype typt terwijl
    /// er tekst geselecteerd is (bv. ** over "vet"), wordt de selectie omklikt:
    /// **vet** met de selectie op "vet". Zonder selectie wordt de cursor na het
    /// gesloten paar geplaatst (bv. **|). Weerspiegelt MacDown's inline-formatting.
    /// `selection` is het huidige selectiebereik VÓÓR het getypte teken.
    static func delimiterWrap(beforeCaret text: String, caret: Int, typed: String, selection: NSRange) -> Completion? {
        let src = text as NSString
        let caret = min(caret, src.length)
        let sel = selection
        let delims = ["**", "*", "_", "`", "~~"]
        guard delims.contains(typed) else { return nil }
        if sel.length > 0 {
            // Omklik de geselecteerde tekst met het delimiterpaar.
            let inner = src.substring(with: sel)
            let insert = typed + inner + typed
            return Completion(insert: insert, replaceRange: sel, caretOffset: insert.count)
        }
        // Zonder selectie doen we niets: het delimiter wordt gewoon getypt.
        // (De 'caret tussen een bestaand paar' case is ambiguous met de
        //  standaard toetsenindiening en kan onverwachte transformaties geven.)
        return nil
    }

    /// Link-aanvulling: nadat de gebruiker "](" typt direct na een "]", voeg
    /// "https://" in en selecteer die, of plaats de caret erin. Weerspiegelt
    /// MacDown's link-autocomplete.
    static func linkCompletion(beforeCaret text: String, caret: Int) -> Completion? {
        let src = text as NSString
        let caret = min(caret, src.length)
        guard caret >= 2 else { return nil }
        let last2 = src.substring(with: NSRange(location: caret - 2, length: 2))
        guard last2 == "](" else { return nil }
        return Completion(insert: "https://", caretOffset: 8)
    }

    /// Combineert de bovenstaande voorstellen voor één toetsenindiening.
    /// `typed` is de letter/teken dat net is getypt; `isReturn` markeert Enter.
    static func completion(beforeCaret text: String, caret: Int, typed: String, selection: NSRange, isReturn: Bool) -> Completion? {
        if isReturn { return listContinuation(beforeCaret: text, caret: caret) }
        if let c = linkCompletion(beforeCaret: text, caret: caret) { return c }
        if let c = delimiterWrap(beforeCaret: text, caret: caret, typed: typed, selection: selection) { return c }
        return nil
    }
}
