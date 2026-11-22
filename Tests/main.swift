import AppKit
import WebKit

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
if CommandLine.arguments.contains("--parser-only") { print("\(failures) failures");exit(failures==0 ? 0:1) }
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
