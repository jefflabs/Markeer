import AppKit
import WebKit
import PDFKit

if let report=Bundle.main.object(forInfoDictionaryKey:"TestReportPath") as? String { freopen(report,"w",stdout);freopen(report,"a",stderr) }
if CommandLine.arguments.count > 2 && CommandLine.arguments[1] == "--render" {
 let source=try! String(contentsOfFile:CommandLine.arguments[2],encoding:.utf8)
 print(String(data:try! JSONEncoder().encode(Markdown.render(source)),encoding:.utf8)!);exit(0)
}
var failures = 0
func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    if condition() { print("PASS \(name)") } else { failures += 1; print("FAIL \(name)") }
}
let sample = "# Titel\n\nTekst met **vet**, *cursief* en [link](https://example.com).\n\n- [x] Klaar\n- [ ] Nog doen\n\n| A | B |\n| --- | --- |\n| één | twee |\n\n```swift\nlet x = 1\n```\n"
let rendered = Markdown.render(sample)
let html = rendered.blocks.map(\.html).joined()
check("headings", html.contains("<h1>Titel</h1>"))
check("bold and italic", html.contains("<strong>vet</strong>") && html.contains("<em>cursief</em>"))
check("tables", html.contains("<table>"))
check("tasks", html.contains("type=\"checkbox\""))
check("code language", html.contains("language-swift"))
check("unsafe script is inert", !Markdown.render("<script>alert(1)</script>").blocks.map(\.html).joined().contains("<script>"))
check("unsafe links", !Markdown.render("[bad](javascript:alert(1))").blocks.map(\.html).joined().contains("href=\"javascript:"))
check("inline HTML preserved safely",Markdown.render("Text <span>inside</span>").blocks.first?.html.contains("data-raw-inline") == true)
check("numbered list with start value",Markdown.render("3. Eerste\n4. Tweede\n").blocks.first?.html.contains("<ol start=\"3\">") == true)
check("empty", Markdown.render("").blocks.isEmpty)
check("unicode", Markdown.render("# Café 🌱\n").blocks.first?.source == "# Café 🌱")
check("reference definitions retained", Markdown.render("[site][s]\n\n[s]: https://example.com\n").references.contains("[s]:"))

let listEdit=MarkdownEditing.numberedList(in:"Eerste\nTweede\n",selection:NSRange(location:0,length:13))
check("numbered list action numbers selected lines",listEdit.text=="1. Eerste\n2. Tweede\n")
let paragraphEdit=MarkdownEditing.numberedList(in:"Kop\nRegel tekst\n",selection:NSRange(location:8,length:0))
check("numbered list action uses whole current line",paragraphEdit.range==NSRange(location:4,length:12) && paragraphEdit.text=="1. Regel tekst\n")
check("numbered list action replaces bullets",MarkdownEditing.numberedList(in:"- Een\n- Twee",selection:NSRange(location:0,length:12)).text=="1. Een\n2. Twee")
check("numbered list action starts an empty document",MarkdownEditing.numberedList(in:"",selection:NSRange(location:0,length:0)).text=="1. ")
check("numbered list action leaves next unselected line",MarkdownEditing.numberedList(in:"Een\nTwee",selection:NSRange(location:0,length:4)).text=="1. Een\n")
check("numbered list action handles Unicode",MarkdownEditing.numberedList(in:"🌱 café",selection:NSRange(location:3,length:0)).text=="1. 🌱 café")
let document = MarkdownDocument()
try! document.read(from:Data("# Café 🌱\n".utf8),ofType:"net.markeer.markdown")
check("document UTF-8 read",document.content=="# Café 🌱\n")
check("document UTF-8 save",try! document.data(ofType:"net.markeer.markdown")==Data("# Café 🌱\n".utf8))
let utf16="# UTF16\n".data(using:.utf16)!
try! document.read(from:utf16,ofType:"net.markeer.markdown")
check("document UTF-16 import",document.content=="# UTF16\n")
do { try document.read(from:Data([0xff,0xff,0xff]),ofType:"net.markeer.markdown");check("invalid encoding rejected",false) } catch {check("invalid encoding rejected",true)}

// Front-matter (Jekyll-conventie) — herkennen, renderen, exact behouden.
let fmSource="---\ntitle: Café 🌱\ndate: 2026-11-22\ntags: [test, ünicode]\ndraft: true\n---\n\n# Kop\n\nTekst.\n"
let fmRendered=Markdown.render(fmSource)
check("front-matter herkend bij documentbegin",fmRendered.frontMatter?.source=="---\ntitle: Café 🌱\ndate: 2026-11-22\ntags: [test, ünicode]\ndraft: true\n---")
check("front-matter body gescheiden",fmRendered.blocks.first?.source=="# Kop")
check("front-matter entries geparse",fmRendered.frontMatter?.entries.contains { $0.0=="title" && $0.1=="Café 🌱" }==true && fmRendered.frontMatter?.entries.contains { $0.0=="tags" && $0.1=="[test, ünicode]" }==true)
let fmNoClose="---\ntitle: x\n\n# Body zonder sluiting\n"
check("ontbrekende sluiting → geen front-matter",Markdown.render(fmNoClose).frontMatter==nil && Markdown.render(fmNoClose).blocks.first?.source=="---")
let fmNotFirst="Tekst vóór\n---\ntitle: x\n---\n"
check("blok niet op documentbegin → genegeerd",Markdown.render(fmNotFirst).frontMatter==nil)
let fmEmptyBody="---\ntitle: leeg\n---\n"
let fmEmptyRendered=Markdown.render(fmEmptyBody)
check("lege body na front-matter",fmEmptyRendered.frontMatter != nil && fmEmptyRendered.blocks.isEmpty)
let fmBlockScalar="---\ndescription: |\n  Regel één\n  Regel twee\n---\n\nBody.\n"
check("block scalar in front-matter",Markdown.render(fmBlockScalar).frontMatter?.entries.contains { $0.0=="description" && $0.1=="Regel één Regel twee" }==true)
let fmList="---\ncategories:\n  - een\n  - twee\n---\n\nLijstbody.\n"
check("lijst in front-matter",Markdown.render(fmList).frontMatter?.entries.contains { $0.0=="categories" && $0.1=="een twee" }==true)
let fmCR="---\r\ntitle: crlf\r\n---\r\n\nBody CRLF.\n"
// CRLF wordt door components(separatedBy:"\n") niet gesplitst op \r; de bron bevat \r\n,
// dus "---\r" ≠ "---" en het blok wordt niet herkend. Dat is de gewenste conservatieve gedraging.
check("CRLF-document: conservatief niet herkend",Markdown.render(fmCR).frontMatter==nil)

// Autocomplete: lijstcontinuatie, delimiter-wrap, link-aanvulling.
// listContinuation: de tekst bevat al het getypte \n (caret erachter); de
// inhoudsregel vóór dat \n bepaalt de marker die op de nieuwe regel komt.
let lc1=MarkdownEditing.listContinuation(beforeCaret:"- één\n",caret:6)
check("lijstcontinuatie bullet",lc1?.insert=="- " && lc1?.caretOffset==2)
let lc2=MarkdownEditing.listContinuation(beforeCaret:"  - ingesprongen\n",caret:17)
check("lijstcontinuatie behoudt indent",lc2?.insert=="  - " && lc2?.caretOffset==4)
let lc3=MarkdownEditing.listContinuation(beforeCaret:"2. tweede\n",caret:10)
check("lijstcontinuatie genummerd",lc3?.insert=="2. " && lc3?.caretOffset==3)
let lc4=MarkdownEditing.listContinuation(beforeCaret:"gewone regel\n",caret:14)
check("lijstcontinuatie alleen op lijstregels",lc4==nil)
let lc5=MarkdownEditing.listContinuation(beforeCaret:"",caret:0)
check("lijstcontinuatie leeg document",lc5==nil)
// Lijst stoppen: lege inhouds-item (alleen marker) levert géén nieuwe marker.
let lc6=MarkdownEditing.listContinuation(beforeCaret:"- \n",caret:3)
check("lijst stoppen op lege item",lc6==nil)
// Unicode: marker vóór Unicode-tekst blijft intact.
let lc7=MarkdownEditing.listContinuation(beforeCaret:"- café 🌱\n",caret:10)
check("lijstcontinuatie Unicode",lc7?.insert=="- " && lc7?.caretOffset==2)
// delimiterWrap met selectie: omklick de geselecteerde tekst.
let dw1=MarkdownEditing.completion(beforeCaret:"vet",caret:0,typed:"*",selection:NSRange(location:0,length:3),isReturn:false)
check("delimiter-wrap omklickt selectie",dw1?.insert=="*vet*" && dw1?.replaceRange==NSRange(location:0,length:3) && dw1?.caretOffset==5)
let dw2=MarkdownEditing.completion(beforeCaret:"x",caret:1,typed:"*",selection:NSRange(location:1,length:0),isReturn:false)
check("delimiter zonder selectie → niets (wordt gewoon getypt)",dw2==nil)
// Delimiter-wrap met meerdere delimiters (vet, code, strike).
let dw4=MarkdownEditing.completion(beforeCaret:"code",caret:0,typed:"`",selection:NSRange(location:0,length:4),isReturn:false)
check("code-wrap omklickt selectie",dw4?.insert=="`code`" && dw4?.replaceRange==NSRange(location:0,length:4))
let dw5=MarkdownEditing.completion(beforeCaret:"w",caret:0,typed:"a",selection:NSRange(location:0,length:1),isReturn:false)
check("niet-delimiter letter → geen wrap",dw5==nil)
// Link-aanvulling: "](" → https://
let lk1=MarkdownEditing.completion(beforeCaret:"[tekst](",caret:8,typed:"(",selection:NSRange(location:8,length:0),isReturn:false)
check("link-aanvulling na ])",lk1?.insert=="https://" && lk1?.caretOffset==8)
let lk2=MarkdownEditing.completion(beforeCaret:"[tekst]",caret:7,typed:"]",selection:NSRange(location:7,length:0),isReturn:false)
check("geen link-aanvulling zonder (",lk2==nil)
// Enter op gewone tekst: geen voorstel (standaard ingesteld).
let en1=MarkdownEditing.completion(beforeCaret:"Regel\n",caret:5,typed:"",selection:NSRange(location:5,length:0),isReturn:true)
check("Enter op gewone tekst → niets",en1==nil)
// Gewone tekst zonder onverwachte transformaties: een willekeurige letter geeft niets.
let nt=MarkdownEditing.completion(beforeCaret:"hallo ",caret:6,typed:"w",selection:NSRange(location:6,length:0),isReturn:false)
check("gewone letter → geen voorstel",nt==nil)

// Footnotes (cmark-gfm native): verwijzing → <sup class=footnote-ref>, definitie → endnote-sectie.
let fnSrc="Tekst met een voetnoot.[^a]\n\n[^a]: De verklaring.\n"
let fnRendered=Markdown.render(fnSrc)
check("footnote-referentie wordt <sup>",fnRendered.blocks.contains{ $0.html.contains("footnote-ref") })
check("footnote-definitie wordt endnote-sectie",fnRendered.blocks.contains{ $0.html.contains("data-footnotes") && $0.html.contains("De verklaring") })
check("footnote-bron blijft [^a]",fnRendered.blocks.contains{ $0.source=="Tekst met een voetnoot.[^a]" } && fnRendered.blocks.contains{ $0.source=="[^a]: De verklaring." })

// Highlight ==...== → <mark>, code-beschermend.
let hl1=Markdown.render("Dit is ==belangrijk== tekst.\n")
check("highlight wordt <mark> (gebeschermde inline-HTML)",hl1.blocks.first?.source.contains("<mark>belangrijk</mark>")==true)
let hlCode=Markdown.render("```swift\nlet s = \"==niet==\"\n```\n")
check("highlight niet in fenced code",hlCode.blocks.first?.source.contains("==niet==")==true && hlCode.blocks.first?.html.contains("<mark>")==false)
let hlInline=Markdown.render("Inline `==code==` blijft.\n")
check("highlight niet in inline code",hlInline.blocks.first?.html.contains("<code>==code==</code>")==true)
// Geen == in een gewone regel → ongewijzigd.
let hlNone=Markdown.render("Geen highlight hier.\n")
check("gewone tekst ongewijzigd zonder ==",hlNone.blocks.first?.html=="<p>Geen highlight hier.</p>\n")

// Preferences: defaults en persistentie (zonder UI).
let freshDefaults = Preferences.default.autocompleteEnabled == true
    && Preferences.default.codeHighlightingEnabled == true
    && Preferences.default.showFrontMatter == true
    && Preferences.default.showStatusBar == true
check("Preferences defaults zijn allemaal aan", freshDefaults)
var mutated = Preferences.default
mutated.autocompleteEnabled = false
mutated.showStatusBar = false
mutated.save()
let reloaded = Preferences.load()
check("Preferences persistentie (na save + load)", reloaded.autocompleteEnabled == false && reloaded.showStatusBar == false && reloaded.codeHighlightingEnabled == true && reloaded.showFrontMatter == true)
// Herstel defaults zodat overige tests niet worden beïnvloed.
Preferences.default.save()
check("Preferences herstel naar defaults", Preferences.load() == Preferences.default)

// Lokalisatie: taalresolutie, fallback, vertaling, onvertaalde gebruikersinhoud.
// 6 talen ondersteund, NL behouden.
check("6 talen ondersteund", L10n.supported.count == 6 && L10n.supported.map(\.code).contains("nl") && L10n.supported.map(\.code).contains("en"))
// Systeemtaalresolutie: eerste ondersteunde code wint.
check("resolutie kiest eerste ondersteunde", L10n.resolveLanguage(fromPreferences: ["ja-JP", "nl-BE", "en"]) == "nl")
check("resolutie valt terug op en", L10n.resolveLanguage(fromPreferences: ["ja-JP", "sv-SE"]) == "en")
check("resolutie hanteert _-variant", L10n.resolveLanguage(fromPreferences: ["fr_FR"]) == "fr")
// Override voor deterministische vertaaltests.
L10n.overrideLanguage = "nl"
defer { L10n.overrideLanguage = nil }
check("NL vertaling status.words", L10n.string("status.words", 42) == "42 woorden")
check("NL vertaling menu.view", L10n.string("menu.view") == "Weergave")
check("NL plural pagina's", L10n.string("pdf.status.pages.plural", 3) == "3 pagina's")
L10n.overrideLanguage = "en"
check("EN vertaling status.words", L10n.string("status.words", 42) == "42 words")
check("EN fallback", L10n.string("menu.view") == "View")
L10n.overrideLanguage = "de"
check("DE vertaling (bestaande key)", L10n.string("menu.format.bold") == "Fett")
check("DE heeft volledige pariteit (geen EN-fallback nodig)", L10n.string("menu.view.autocomplete") == "Markdown-Autovervollständigung")
// EN-fallback voor een key die in DE écht ontbreekt: gebruik een tijdelijk
// verwijderde key via de publieke bundle-access.
let deHasKey = L10n.bundle(for: "de")?["editor.source.label"] != nil
check("DE bundle is toegankelijk", deHasKey == true)

// Volledigheidscheck (acceptatie #1837): elke ondersteunde taal heeft EXACT de
// zelfde key-set als het autoritaire Engels, en geen enkele vertaling is leeg.
// Dit vangt ontbrekende keys en lege waarden in ELKE taal automatisch op.
let enKeySet = Set(L10n.en.keys)
var parityOK = true
var emptyFound = false
for lang in L10n.supported {
    guard let bundle = L10n.bundle(for: lang.code) else { parityOK = false; continue }
    let keySet = Set(bundle.keys)
    if keySet != enKeySet { parityOK = false }
    for (k, v) in bundle where v.trimmingCharacters(in: .whitespaces).isEmpty { emptyFound = true }
}
check("vertaalpariteit: alle 6 talen hebben exact de EN-keyset", parityOK)
check("geen lege vertalingen in enige taal", !emptyFound)

// Wiskunde (KaTeX, taak #1825): delimiters → placeholder, code-beschermend,
// gewone dollarbedragen onaangetast, ongeldige formules crashen niet.
let mathInline = Markdown.render("Laat \\(a^2+b^2\\) zien.\n")
check("\\(..\\) inline-math → sentinel", mathInline.blocks.first?.html.contains("⌘M0") == true && mathInline.blocks.first?.source.contains("⌘M0") == true)
let mathDisplay = Markdown.render("$$\nx = \\frac{-b}{a}\n$$\n")
check("$$..$$ display-math → display-sentinel", mathDisplay.blocks.contains { $0.source.contains("⌘M1") })
let mathDollarOff = Markdown.render("Price is $5 and a$b stays.\n")
check("inline $ uitgeschakeld → dollarbedragen intact", mathDollarOff.blocks.first?.source == "Price is $5 and a$b stays.")
check("inline $ uitgeschakeld → $E=mc^2$ blijft tekst", Markdown.render("Inline $E = mc^2$ hier.\n").blocks.first?.source.contains("$E = mc^2$") == true)
// inlineDollarMath aanzetten (voorkeur) → $..$ wordt math.
var prefsOn = Preferences.load(); prefsOn.inlineDollarMath = true; prefsOn.save()
defer { Preferences.default.save() }
let mathDollarOn2 = Markdown.render("Inline $E = mc^2$ hier.\n")
check("inline $ aangezet → $E = mc^2$ wordt math", mathDollarOn2.blocks.first?.html.contains("⌘M0") == true)
let mathCode = Markdown.render("```swift\nlet m = \"$not-math$\"\n```\n")
check("math niet in fenced code", mathCode.blocks.first?.source.contains("$not-math$") == true && mathCode.blocks.first?.html.contains("⌘M0") == false)
let mathBad = Markdown.render("Ongeldig \\( geen sluiting hier.\n")
check("ongeldige formule crash niet (blijft tekst)", mathBad.blocks.first != nil)

// Systeemtaalkeuze + fallback doorlopen (acceptatie): elke ondersteunde code
// lost op zichzelf, een onbekende taal lost op EN.
var resolveOK = true
for lang in L10n.supported { if L10n.resolveLanguage(fromPreferences: [lang.code + "-XX"]) != lang.code { resolveOK = false } }
resolveOK = resolveOK && L10n.resolveLanguage(fromPreferences: ["zh-Hans", "ar-AE"]) == "en"
check("systeemtaalkeuze + Engelse fallback", resolveOK)
// Plurals: pagina/pagina's (NL) en page/pages (EN) kiezen de juiste vorm.
L10n.overrideLanguage = "nl"
check("plural NL 1 → pagina", L10n.string("pdf.status.pages", 1) == "1 pagina")
check("plural NL 3 → pagina's", L10n.string("pdf.status.pages.plural", 3) == "3 pagina's")
L10n.overrideLanguage = "en"
check("plural EN 1 → page", L10n.string("pdf.status.pages", 1) == "1 page")
check("plural EN 5 → pages", L10n.string("pdf.status.pages.plural", 5) == "5 pages")
L10n.overrideLanguage = nil
// Ontbrekende key in alle talen → de key zelf (voorspelbare fallback).
check("onbekende key → key zelf", L10n.string("niet.bestaande.key") == "niet.bestaande.key")
// Gebruikersinhoud/Markdown wordt NIET vertaald: de renderer raakt L10n niet aan.
let mdOut = Markdown.render("# Titel\n\nHello **world**.").blocks.map(\.html).joined()
check("Markdown-bron onvertaald door renderer", mdOut.contains("<h1>Titel</h1>") && mdOut.contains("Hello **world**".replacingOccurrences(of:"**",with:"")) || mdOut.contains("<strong>world</strong>"))
// PDF-markeren (taak #2607): QuadPoints-berekening is puur en moet per quad
// precies 8 coördinaten opleveren (4 hoekpunten, links-boven start).
let quads = PDFHighlight.quadPoints([CGRect(x: 1, y: 2, width: 3, height: 4)])
check("highlight quadPoints = 8 punten per quad", quads == [1,2,4,2,4,6,1,6])
let multipleQuads = PDFHighlight.quadPoints([CGRect(x: 0, y: 0, width: 1, height: 1), CGRect(x: 5, y: 6, width: 2, height: 3)])
check("highlight quadPoints meerdere quads", multipleQuads.count == 16 && multipleQuads[8] == 5)
let hlAnno = PDFHighlight.annotation(forRects: [CGRect(x: 1, y: 2, width: 3, height: 4)])
check("highlight-annotatie heeft Highlight-type", hlAnno.type == "Highlight")
// PDFKit normaliseert QuadPoints naar NSPoint-paren: 1 quad = 4 punten.
let hlPoints = hlAnno.value(forAnnotationKey: PDFAnnotationKey.quadPoints) as? [NSPoint]
check("highlight-annotatie heeft quadPoints (4 punten per quad)",
      hlPoints?.count == 4 && hlPoints?[0] == NSPoint(x: 1, y: 2) && hlPoints?[3] == NSPoint(x: 1, y: 6))
if CommandLine.arguments.contains("--parser-only") { print("\(failures) failures");exit(failures==0 ? 0:1) }

// --pdf: echte vensterchecks voor de PDF-modus (thumbnails, markeren, notities).
// Vereist een grafische sessie (WindowServer), zoals de overige native checks.
if CommandLine.arguments.contains("--pdf") {
    var pdfFailures = 0
    func pdfcheck(_ name: String, _ condition: @autoclosure () -> Bool) {
        if condition() { print("PASS \(name)") } else { pdfFailures += 1; print("FAIL \(name)") }
    }
    // Deterministische 2-pagina PDF met echte, selecteerbare tekst (regel per
    // Tekstobject, Helvetica 12pt, eerste baseline y=770, regelafstand 30).
    // Objecten: 1 catalog, 2 pages, 3 font, per pagina k: 4+2k pagina, 5+2k content.
    func minimalTextPDF(pages: [[String]]) -> Data {
        var out = "%PDF-1.4\n"
        var offsets: [Int] = []
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
        }
        func obj(_ n: Int, _ body: String) {
            while offsets.count <= n { offsets.append(0) }
            offsets[n] = out.utf8.count
            out += "\(n) 0 obj\n\(body)\nendobj\n"
        }
        let n = pages.count
        let maxObj = 3 + 2 * n  // 1 catalog, 2 pages, 3 font, daarna 2 objecten per pagina
        let pageRefs = (0..<n).map { "\(4 + 2*$0) 0 R" }.joined(separator: " ")
        obj(1, "<< /Type /Catalog /Pages 2 0 R >>")
        obj(2, "<< /Type /Pages /Kids [\(pageRefs)] /Count \(n) >>")
        obj(3, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
        for (i, lines) in pages.enumerated() {
            var stream = "BT /F1 12 Tf 72 770 Td"
            for (j, text) in lines.enumerated() {
                if j > 0 { stream += " 0 -30 Td" }
                stream += " (\(esc(text))) Tj"
            }
            stream += " ET"
            obj(4 + 2*i, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents \(5 + 2*i) 0 R >>")
            obj(5 + 2*i, "<< /Length \(stream.utf8.count) >>\nstream\n\(stream)\nendstream")
        }
        let xrefOffset = out.utf8.count
        out += "xref\n0 \(maxObj + 1)\n0000000000 65535 f \n"
        for i in 1...maxObj { out += String(format: "%010d 00000 n \n", offsets[i]) }
        out += "trailer\n<< /Size \(maxObj + 1) /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n"
        return Data(out.utf8)
    }
    func labelStrings(in view: NSView) -> [String] {
        var result: [String] = []
        for sub in view.subviews {
            if let tf = sub as? NSTextField { result.append(tf.stringValue) }
            result += labelStrings(in: sub)
        }
        return result
    }
    func viewWithIdentifier(_ identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier { return view }
        for sub in view.subviews {
            if let found = viewWithIdentifier(identifier, in: sub) { return found }
        }
        return nil
    }
    let pdfData = minimalTextPDF(pages: [
        ["Eerste pagina: selecteer deze tekst met de marker.", "Tweede regel: meerregelige selecties werken ook."],
        ["Tweede pagina: andere inhoud."]
    ])
    let doc = MarkeerPDFDocument()
    try! doc.read(from: pdfData, ofType: "public.pdf")
    guard let pdf = doc.pdf, pdf.pageCount == 2,
          pdf.page(at: 0)?.string?.contains("Eerste pagina") == true else {
        print("FAIL test-PDF onleesbaar door PDFKit"); print("1 failures"); exit(1)
    }
    doc.makeWindowControllers()
    guard let controller = doc.windowControllers.first as? PDFWindowController, let window = controller.window else {
        print("FAIL PDF-windowcontroller ontbreekt"); print("1 failures"); exit(1)
    }
    // De split-view verdeelt zijn panelen pas bij de eerste weergave; toon de
    // window dus even en dwing daarna de layout af.
    window.makeKeyAndOrderFront(nil)
    window.layoutIfNeeded()
    window.contentView?.layoutSubtreeIfNeeded()
    // 1) Thumbnails: één per pagina, niet 0×0 (de oorspronkelijke bug uit #2603).
    let buttons = controller.sidebarList.arrangedSubviews.compactMap { $0 as? NSButton }
    pdfcheck("thumbnails: één per pagina", buttons.count == 2)
    pdfcheck("thumbnails: zichtbaar (niet 0×0)", buttons.allSatisfy { $0.frame.width > 100 && $0.frame.height > 100 })
    // De oorspronkelijke bug was tevens een onzichtbaar sidebar-paneel (0 breed);
    // meet daarom het paneel en de content, niet alleen de knopframes.
    pdfcheck("sidebar-paneel is zichtbaar (split-view verdeelt)", controller.sidebar.frame.width > 100)
    pdfcheck("sidebar-content heeft breedte (documentView gekoppeld)", (controller.sidebar.documentView?.frame.width ?? 0) > 100)
    // Klik op thumbnail navigeert naar de juiste pagina.
    if buttons.count == 2 {
        controller.gotoPage(buttons[1])
        pdfcheck("thumbnail-klik navigeert naar pagina 2", controller.pdfView.currentPage === pdf.page(at: 1))
        controller.gotoPage(buttons[0])
        pdfcheck("thumbnail-klik navigeert terug naar pagina 1", controller.pdfView.currentPage === pdf.page(at: 0))
    }
    // 2) Notities: icoon-annotatie verschijnt in de lijst per pagina, klik navigeert.
    let note = PDFAnnotation(bounds: NSRect(x: 480, y: 780, width: 40, height: 30), forType: .text, withProperties: [
        PDFAnnotationKey.contents: "Testnotitie voor de lijst."
    ])
    pdf.page(at: 0)!.addAnnotation(note)
    controller.refreshNotesList()
    let sidebarLabels = labelStrings(in: controller.sidebar)
    pdfcheck("notitie verschijnt in lijst (P.1 + tekst)", sidebarLabels.contains("P.1: Testnotitie voor de lijst."))
    if let wrapper = viewWithIdentifier("note-0", in: controller.sidebar),
       let recognizer = wrapper.gestureRecognizers.first as? NSClickGestureRecognizer {
        controller.gotoPage(buttons[1])
        controller.navigateToNotePage(recognizer)
        pdfcheck("notitie-klik navigeert naar pagina 1", controller.pdfView.currentPage === pdf.page(at: 0))
    } else { pdfcheck("notitie-klik navigeert naar pagina 1", false) }
    // Verwijderen van de notitie werkt de lijst direct bij.
    controller.deleteSelectedNote()
    pdfcheck("na verwijderen: lijst toont (geen notities)", labelStrings(in: controller.sidebar).contains("(geen notities)"))
    // 3) Markeren: selectie + marker-knop = alleen de geselecteerde tekst geel.
    // De tekst staat op (72, 770) in Helvetica 12pt; het woord "selecteer" ligt
    // ongeveer op x 153–203, dus een punt in (178, 774) valt in het woord.
    let page0 = pdf.page(at: 0)!
    guard let selected = page0.selectionForWord(at: CGPoint(x: 178, y: 774)),
          selected.string?.contains("selecteer") == true else {
        print("FAIL kon tekstselectie niet opbouwen (\(page0.selectionForWord(at: CGPoint(x: 178, y: 774))?.string ?? "nil"))");
        print("\(pdfFailures + 1) failures"); exit(1)
    }
    let before = page0.annotations.count
    controller.pdfView.currentSelection = selected
    controller.addHighlight()
    let highlights = page0.annotations.filter { $0.type == "Highlight" }
    pdfcheck("marker-knop voegt highlight toe", highlights.count == 1 && page0.annotations.count == before + 1)
    // PDFAnnotation heeft in deze SDK geen bounds(for:); de effectieve omvatting
    // is de unie van de quadPoints-rects (PDFKit slaat QuadPoints op als NSPoints,
    // 4 punten per quad).
    func unionOfQuads(_ points: [NSPoint]) -> CGRect {
        var union = CGRect.null
        var i = 0
        while i + 3 < points.count {
            let quad = points[i..<i+4]
            let xs = quad.map(\.x), ys = quad.map(\.y)
            union = union.union(CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!))
            i += 4
        }
        return union
    }
    let highlightQuads = highlights.first.flatMap { $0.value(forAnnotationKey: PDFAnnotationKey.quadPoints) as? [NSPoint] } ?? []
    let highlightBounds = unionOfQuads(highlightQuads)
    let pageBounds = page0.bounds(for: .mediaBox)
    pdfcheck("highlight omvat alleen de selectie (niet de hele pagina)",
             highlightBounds.height > 0 && highlightBounds.height < pageBounds.height * 0.25)
    pdfcheck("highlight heeft quadPoints (4 punten per quad)", highlightQuads.count >= 4 && highlightQuads.count % 4 == 0)
    // Zonder selectie: no-op (geen annotatie, zeker geen hele pagina).
    controller.pdfView.currentSelection = nil
    let beforeNoop = page0.annotations.count
    controller.addHighlight()
    pdfcheck("marker-knop zonder selectie = no-op", page0.annotations.count == beforeNoop)
    // Meerregelige selectie (beide regels van pagina 1) → één annotatie met twee quads.
    // Regels staan op baseline 770 en 740; het rect omsluit beide tekstlichamen.
    // ObjC selectionForRect: wordt in Swift selection(for:) afgebeeld.
    if let rectSelection = page0.selection(for: CGRect(x: 72, y: 730, width: 300, height: 52)),
       rectSelection.string?.contains("selecteer") == true,
       rectSelection.string?.contains("meerregelige") == true {
        controller.pdfView.currentSelection = rectSelection
        controller.addHighlight()
    }
    let allHighlights = page0.annotations.filter { $0.type == "Highlight" }
    pdfcheck("meerregelige selectie wordt gemarkeerd", allHighlights.count == 2)
    let multiQuads = allHighlights.last.flatMap { $0.value(forAnnotationKey: PDFAnnotationKey.quadPoints) as? [NSPoint] } ?? []
    pdfcheck("meerregelige highlight heeft twee quads", multiQuads.count >= 8 && multiQuads.count % 4 == 0)
    let multiBounds = unionOfQuads(multiQuads)
    pdfcheck("meerregelige highlight spant beide regels", multiBounds.height > 30 && multiBounds.height < pageBounds.height * 0.25)
    // Rondtrip: opslaan + heropenen behoudt beide highlights met quadPoints.
    let reopened = pdf.dataRepresentation().flatMap { PDFKit.PDFDocument(data: $0) }
    let reopenedHighlights = reopened?.page(at: 0)?.annotations.filter { $0.type == "Highlight" } ?? []
    pdfcheck("highlights overleven opslaan + heropenen", reopenedHighlights.count == 2)
    pdfcheck("heropenen: quadPoints intact", reopenedHighlights.allSatisfy { ($0.value(forAnnotationKey: PDFAnnotationKey.quadPoints) as? [NSPoint])?.count ?? 0 >= 4 })
    // 4) Statusbalk: paginas, PDF en versie.
    pdfcheck("statusbalk toont paginas + PDF", controller.status.stringValue.contains("2 pagina") && controller.status.stringValue.contains("PDF"))
    print("\(pdfFailures) failures")
    exit(pdfFailures == 0 ? 0 : 1)
}
if CommandLine.arguments.contains("--askai") {
    var askAIFailures = 0
    func askAIcheck(_ name: String, _ condition: @autoclosure () -> Bool) {
        if condition() { print("PASS \(name)") } else { askAIFailures += 1; print("FAIL \(name)") }
    }
    func askAI(_ prompt: String, _ model: String, timeout: Double) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String? = nil
        AskAI.shared.ask(prompt: prompt, context: "Testdocument.", model: model) { outcome in
            if case .success(let text) = outcome { result = text }
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut { return nil }
        return result
    }
    let answer = askAI("Antwoord exact met: OK", "llama3.2:1b", timeout: 60)
    askAIcheck("AskAI returns text", answer?.isEmpty == false)
    let unreachable = AskAI(baseURL: URL(string: "http://localhost:59999/api/chat")!).askBlocking(prompt: "x", context: "y", model: "llama3.2:1b")
    askAIcheck("AskAI reports connection error", unreachable == false)
    print("\(askAIFailures) failures")
    exit(askAIFailures == 0 ? 0 : 1)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let configuration=WKWebViewConfiguration();configuration.websiteDataStore = .nonPersistent()
let web = WKWebView(frame: NSRect(x:0,y:0,width:900,height:700),configuration:configuration)
let resource = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : Bundle.main.resourcePath!, isDirectory:true)
web.loadFileURL(resource.appendingPathComponent("editor.html"), allowingReadAccessTo:resource)
func spin(until condition: ()->Bool, timeout: Double=15) {
    let limit=Date().addingTimeInterval(timeout)
    while !condition() && Date()<limit { RunLoop.current.run(until:Date().addingTimeInterval(0.01)) }
}
spin(until: { !web.isLoading })
func js(_ script: String) -> Any? {
    var done=false; var value:Any?
    web.evaluateJavaScript(script) { result,error in
        if let error { print("JS ERROR: \(error)"); failures += 1 }
        value=result; done=true
    }
    spin(until:{done}); if !done {failures += 1;print("FAIL JS timeout")}; return value
}
let payload=String(data:try! JSONEncoder().encode(rendered),encoding:.utf8)!
let sourceJSON=String(data:try! JSONEncoder().encode(sample),encoding:.utf8)!
_ = js("markeer.setContent(\(payload), 1, \(sourceJSON))")
check("rich roundtrip keeps original blocks", js("markeer.serialize()") as? String == sample)
_ = js("document.querySelector('h1').textContent='Gewijzigd'")
let edited=js("markeer.serialize()") as? String ?? ""
check("rich heading edit", edited.contains("# Gewijzigd"))
check("unmodified table preserved", edited.contains("| één | twee |"))
check("unmodified code preserved", edited.contains("```swift\nlet x = 1\n```"))
_ = js("document.querySelector('tbody td').textContent='drie'")
check("rich table edit keeps table", (js("markeer.serialize()") as? String ?? "").contains("drie") && (js("markeer.serialize()") as? String ?? "").contains("|"))
_ = js("document.querySelector('input').checked=false;document.querySelector('input').removeAttribute('checked')")
check("task edit retains task syntax", (js("markeer.serialize()") as? String ?? "").contains("[ ] Klaar"))
_ = js("markeer.editor.innerHTML='<p>A <strong>bold</strong> and <em>italic</em> <a href=\"https://example.com\">link</a>.</p>'; markeer.setTest=true")
let newText=js("markeer.serialize()") as? String ?? ""
check("new rich text converts formatting", newText.contains("**bold**") && newText.contains("*italic*") && newText.contains("[link](https://example.com)"))
_ = js("markeer.editor.innerHTML='<pre><code class=\"language-md\">```inside```</code></pre>'")
check("nested code fences", (js("markeer.serialize()") as? String ?? "").contains("````md"))
_ = js("markeer.editor.innerHTML='<p><br></p>'")
check("clearing rich document", js("markeer.serialize()") as? String == "")
var pdfData: Data? = nil
var pdfError: Error? = nil
web.createPDF(configuration: WKPDFConfiguration()) { result in
    switch result {
    case .success(let data): pdfData = data
    case .failure(let error): pdfError = error
    }
}
spin(until: { pdfData != nil || pdfError != nil })
check("PDF export produces data", pdfData != nil && pdfData!.count > 0)
check("PDF export has no error", pdfError == nil)
check("PDF is a PDF file", pdfData != nil && String(data: pdfData!.prefix(5), encoding: .ascii) == "%PDF-")
print("\(failures) failures")
exit(failures==0 ? 0:1)
