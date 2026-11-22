import Foundation

/// Gecentraliseerde lokalisatiestructuur. Alle gebruikersgerichte UI-teksten
/// (knoppen, menus, tooltips, accessibility, status, dialoog, fouten, About)
/// komen hier vandaan. Bron-Markdown en gebruikersinhoud worden NIET vertaald.
///
/// Gedrag: macOS-systeemtaal wordt gevolgd; niet-ondersteunde talen vallen
/// terug op Engels; Nederlands blijft beschikbaar. Ontbrekende keys hebben een
/// voorspelbare fallback (Engels, dan de key zelf). Taalbestanden zijn in
///-process gebundeld en werken dus volledig offline.
enum L10n {
    /// Ondersteunde talen. `code` is de ISO-639-1 code die in de systeemtaal
    /// wordt gematcht; `name` is de endogene naam.
    struct Language: Equatable {
        let code: String
        let name: String
    }

    static let supported: [Language] = [
        .init(code: "nl", name: "Nederlands"),
        .init(code: "en", name: "English"),
        .init(code: "de", name: "Deutsch"),
        .init(code: "fr", name: "Français"),
        .init(code: "it", name: "Italiano"),
        .init(code: "es", name: "Español"),
    ]

    /// Engelse fallback-teksten. Elke key hieronder is het autoritair
    /// vocabulaire; andere talen vullen dezelfde keys in.
    static let en: [String: String] = [
        "app.name": "Markeer",
        "menu.view": "View",
        "menu.view.settings": "Settings…",
        "menu.view.fullscreen": "Full Screen",
        "menu.view.markdown": "Markdown",
        "menu.view.rich": "Formatted",
        "menu.view.split": "Side by Side",
        "menu.view.cycle": "Next view",
        "menu.view.autocomplete": "Markdown auto-completion",
        "menu.edit": "Edit",
        "menu.format": "Format",
        "menu.format.bold": "Bold",
        "menu.format.italic": "Italic",
        "menu.format.heading": "Heading",
        "menu.format.list": "Bullet list",
        "menu.format.numberedList": "Numbered list",
        "menu.format.link": "Link…",
        "menu.file.exportPDF": "Export to PDF…",
        "status.words": "%lld words",
        "status.chars": "%lld characters",
        "status.encoding": "UTF-8",
        "status.mode.markdown": "Markdown",
        "status.mode.rich": "Formatted · directly editable",
        "status.mode.split": "Side by side · both editable",
        "toolbar.new": "New document",
        "toolbar.open": "Open",
        "toolbar.save": "Save",
        "toolbar.exportPDF": "Export to PDF",
        "toolbar.bold": "Bold (⌘B)",
        "toolbar.italic": "Italic (⌘I)",
        "toolbar.heading": "Heading",
        "toolbar.list": "Bullet list",
        "toolbar.numberedList": "Numbered list (⌘⇧O)",
        "toolbar.link": "Insert link",
        "toolbar.mode": "View",
        "toolbar.mode.tooltip": "Switch between Markdown, formatted and side by side (⌘⇧P)",
        "dialog.link.title": "Insert link",
        "dialog.link.info": "Enter the web address. The selected text becomes the link.",
        "dialog.link.insert": "Insert",
        "dialog.link.cancel": "Cancel",
        "editor.source.label": "Markdown editor",
        "editor.rich.placeholder": "Start writing…",
        "error.render": "Rendering error",
        "error.js": "JavaScript error",
        "error.pdf.export": "PDF export error",
        "about.credits": "A quiet place for Markdown.\nNative macOS · local files · three views\n\nBuilt for Jeffrey.",
        "settings.title": "Settings",
        "settings.autocomplete": "Markdown auto-completion in the source editor",
        "settings.highlighting": "Syntax highlighting for code blocks",
        "settings.frontmatter": "Show front-matter metadata in status bar",
        "settings.statusbar": "Show status bar",
        "settings.inlinedollarmath": "Recognize inline math with $...$",
        "settings.ok": "OK",
        "settings.cancel": "Cancel",
        "pdf.note.add.title": "Add annotation",
        "pdf.note.add.info": "Type the note that is added to this page.",
        "pdf.note.add.button": "Add",
        "pdf.note.cancel": "Cancel",
        "pdf.toolbar.addNote": "Add annotation",
        "pdf.toolbar.deleteNote": "Remove annotation",
        "pdf.status.pages": "%lld page",
        "pdf.status.pages.plural": "%lld pages",
        "ai.prompt.placeholder": "Question about this document…",
        "ai.send": "Ask",
        "ai.loading": "Loading…",
        "ai.error": "Error: %@"
    ]

    static let nl: [String: String] = [
        "app.name": "Markeer",
        "menu.view": "Weergave",
        "menu.view.settings": "Instellingen…",
        "menu.view.fullscreen": "Volledig scherm",
        "menu.view.markdown": "Markdown",
        "menu.view.rich": "Opgemaakt",
        "menu.view.split": "Naast elkaar",
        "menu.view.cycle": "Volgende weergave",
        "menu.view.autocomplete": "Markdown-autocomplete",
        "menu.edit": "Wijzig",
        "menu.format": "Opmaak",
        "menu.format.bold": "Vet",
        "menu.format.italic": "Cursief",
        "menu.format.heading": "Kop",
        "menu.format.list": "Opsomming",
        "menu.format.numberedList": "Genummerde lijst",
        "menu.format.link": "Link…",
        "menu.file.exportPDF": "Exporteer naar PDF…",
        "status.words": "%lld woorden",
        "status.chars": "%lld tekens",
        "status.encoding": "UTF-8",
        "status.mode.markdown": "Markdown",
        "status.mode.rich": "Opgemaakt · direct bewerkbaar",
        "status.mode.split": "Naast elkaar · beide bewerkbaar",
        "toolbar.new": "Nieuw document",
        "toolbar.open": "Openen",
        "toolbar.save": "Bewaren",
        "toolbar.exportPDF": "Exporteer naar PDF",
        "toolbar.bold": "Vet (⌘B)",
        "toolbar.italic": "Cursief (⌘I)",
        "toolbar.heading": "Kop",
        "toolbar.list": "Opsomming",
        "toolbar.numberedList": "Genummerde lijst (⌘⇧O)",
        "toolbar.link": "Link invoegen",
        "toolbar.mode": "Weergave",
        "toolbar.mode.tooltip": "Schakel tussen Markdown, opgemaakt en naast elkaar (⌘⇧P)",
        "dialog.link.title": "Link invoegen",
        "dialog.link.info": "Vul het webadres in. De geselecteerde tekst wordt de link.",
        "dialog.link.insert": "Invoegen",
        "dialog.link.cancel": "Annuleren",
        "editor.source.label": "Markdown-editor",
        "editor.rich.placeholder": "Begin met schrijven…",
        "error.render": "Renderfout",
        "error.js": "JavaScript-fout",
        "error.pdf.export": "PDF-exportfout",
        "about.credits": "Een rustige plek voor Markdown.\nNative macOS · lokale bestanden · drie weergaven\n\nGebouwd voor Jeffrey.",
        "settings.title": "Instellingen",
        "settings.autocomplete": "Markdown-autocomplete in de broneditor",
        "settings.highlighting": "Syntaxhighlighting voor codeblokken",
        "settings.frontmatter": "Front-matter-metadata tonen in statusbalk",
        "settings.statusbar": "Statusbalk tonen",
        "settings.inlinedollarmath": "Inline wiskunde met $...$ herkennen",
        "settings.ok": "OK",
        "settings.cancel": "Annuleren",
        "pdf.note.add.title": "Voeg aantekening toe",
        "pdf.note.add.info": "Typ de notitie die aan deze pagina wordt toegevoegd.",
        "pdf.note.add.button": "Toevoegen",
        "pdf.note.cancel": "Annuleren",
        "pdf.toolbar.addNote": "Voeg aantekening toe",
        "pdf.toolbar.deleteNote": "Verwijder aantekening",
        "pdf.status.pages": "%lld pagina",
        "pdf.status.pages.plural": "%lld pagina's",
        "ai.prompt.placeholder": "Vraag over dit document…",
        "ai.send": "Vraag",
        "ai.loading": "Laden…",
        "ai.error": "Fout: %@"
    ]

    // Minimale, correcte vertalingen voor de kern-keys. Ontbrekende keys in een
    // taal vallen voorspelbaar terug op Engels (zie `bundle(for:)`/`string`).
    static let de: [String: String] = [
        "app.name": "Markeer",
        "menu.view": "Ansicht",
        "menu.view.settings": "Einstellungen…",
        "menu.view.fullscreen": "Vollbild",
        "menu.view.markdown": "Markdown",
        "menu.view.rich": "Formatiert",
        "menu.view.split": "Seitlich nebeneinander",
        "menu.view.cycle": "Nächstes Ansicht",
        "menu.edit": "Bearbeiten",
        "menu.format": "Format",
        "menu.format.bold": "Fett",
        "menu.format.italic": "Kursiv",
        "menu.format.heading": "Überschrift",
        "menu.format.list": "Aufzählung",
        "menu.format.numberedList": "Nummerierte Liste",
        "menu.format.link": "Link…",
        "menu.file.exportPDF": "Als PDF exportieren…",
        "status.words": "%lld Wörter",
        "status.chars": "%lld Zeichen",
        "status.mode.markdown": "Markdown",
        "status.mode.rich": "Formatiert · direkt bearbeitbar",
        "status.mode.split": "Nebeneinander · beide bearbeitbar",
        "toolbar.new": "Neues Dokument",
        "toolbar.open": "Öffnen",
        "toolbar.save": "Speichern",
        "dialog.link.title": "Link einfügen",
        "dialog.link.insert": "Einfügen",
        "dialog.link.cancel": "Abbrechen",
        "editor.rich.placeholder": "Mit Schreiben beginnen…",
        "settings.title": "Einstellungen",
        "settings.ok": "OK",
        "settings.cancel": "Abbrechen",
        "status.encoding": "UTF-8",
        "about.credits": "Ein ruhiger Ort für Markdown.\nNative macOS · lokale Dateien · drei Ansichten\n\nGebaut für Jeffrey.",
        "toolbar.exportPDF": "Als PDF exportieren",
        "toolbar.bold": "Fett (⌘B)",
        "toolbar.italic": "Kursiv (⌘I)",
        "toolbar.heading": "Überschrift",
        "toolbar.list": "Aufzählung",
        "toolbar.numberedList": "Nummerierte Liste (⌘⇧O)",
        "toolbar.link": "Link einfügen",
        "toolbar.mode": "Ansicht",
        "toolbar.mode.tooltip": "Zwischen Markdown, formatiert und nebeneinander wechseln (⌘⇧P)",
        "dialog.link.info": "Geben Sie die Webadresse ein. Der markierte Text wird zum Link.",
        "editor.source.label": "Markdown-Editor",
        "error.render": "Renderfehler",
        "error.js": "JavaScript-Fehler",
        "error.pdf.export": "PDF-Exportfehler",
        "settings.autocomplete": "Markdown-Autovervollständigung im Quelleditor",
        "settings.highlighting": "Syntaxhervorhebung für Codeblöcke",
        "settings.frontmatter": "Front-Matter-Metadaten in der Statusleiste anzeigen",
        "settings.statusbar": "Statusleiste anzeigen",
        "settings.inlinedollarmath": "Inline-Mathematik mit $...$ erkennen",
        "pdf.note.add.title": "Annotation hinzufügen",
        "pdf.note.add.info": "Geben Sie die Notiz ein, die zu dieser Seite hinzugefügt wird.",
        "pdf.note.add.button": "Hinzufügen",
        "pdf.note.cancel": "Abbrechen",
        "pdf.toolbar.addNote": "Annotation hinzufügen",
        "pdf.toolbar.deleteNote": "Annotation entfernen",
        "pdf.status.pages": "%lld Seite",
        "pdf.status.pages.plural": "%lld Seiten",
        "ai.prompt.placeholder": "Frage zu diesem Dokument…",
        "ai.send": "Fragen",
        "ai.loading": "Wird geladen…",
        "ai.error": "Fehler: %@",
        "menu.view.autocomplete": "Markdown-Autovervollständigung"
    ]
    static let fr: [String: String] = [
        "app.name": "Markeer",
        "menu.view": "Affichage",
        "menu.view.settings": "Réglages…",
        "menu.view.fullscreen": "Plein écran",
        "menu.view.markdown": "Markdown",
        "menu.view.rich": "Formaté",
        "menu.view.split": "Côte à côte",
        "menu.view.cycle": "Vue suivante",
        "menu.edit": "Édition",
        "menu.format": "Format",
        "menu.format.bold": "Gras",
        "menu.format.italic": "Italique",
        "menu.format.heading": "Titre",
        "menu.format.list": "Liste à puces",
        "menu.format.numberedList": "Liste numérotée",
        "menu.format.link": "Lien…",
        "menu.file.exportPDF": "Exporter en PDF…",
        "status.words": "%lld mots",
        "status.chars": "%lld caractères",
        "status.mode.markdown": "Markdown",
        "status.mode.rich": "Formaté · directement modifiable",
        "status.mode.split": "Côte à côte · les deux modifiables",
        "toolbar.new": "Nouveau document",
        "toolbar.open": "Ouvrir",
        "toolbar.save": "Enregistrer",
        "dialog.link.title": "Insérer un lien",
        "dialog.link.insert": "Insérer",
        "dialog.link.cancel": "Annuler",
        "editor.rich.placeholder": "Commencez à écrire…",
        "settings.title": "Réglages",
        "settings.ok": "OK",
        "settings.cancel": "Annuler",
        "status.encoding": "UTF-8",
        "about.credits": "Un endroit calme pour Markdown.\nmacOS natif · fichiers locaux · trois vues\n\nConçu pour Jeffrey.",
        "toolbar.exportPDF": "Exporter en PDF",
        "toolbar.bold": "Gras (⌘B)",
        "toolbar.italic": "Italique (⌘I)",
        "toolbar.heading": "Titre",
        "toolbar.list": "Liste à puces",
        "toolbar.numberedList": "Liste numérotée (⌘⇧O)",
        "toolbar.link": "Insérer un lien",
        "toolbar.mode": "Affichage",
        "toolbar.mode.tooltip": "Basculer entre Markdown, formaté et côte à côte (⌘⇧P)",
        "dialog.link.info": "Saisissez l'adresse web. Le texte sélectionné devient le lien.",
        "editor.source.label": "Éditeur Markdown",
        "error.render": "Erreur de rendu",
        "error.js": "Erreur JavaScript",
        "error.pdf.export": "Erreur d'export PDF",
        "settings.autocomplete": "Autocomplétion Markdown dans l'éditeur source",
        "settings.highlighting": "Mise en surbrillance de la syntaxe pour les blocs de code",
        "settings.frontmatter": "Afficher les métadonnées front-matter dans la barre d'état",
        "settings.statusbar": "Afficher la barre d'état",
        "settings.inlinedollarmath": "Reconnaître le calcul inline avec $...$",
        "pdf.note.add.title": "Ajouter une annotation",
        "pdf.note.add.info": "Saisissez la note à ajouter à cette page.",
        "pdf.note.add.button": "Ajouter",
        "pdf.note.cancel": "Annuler",
        "pdf.toolbar.addNote": "Ajouter une annotation",
        "pdf.toolbar.deleteNote": "Supprimer l'annotation",
        "pdf.status.pages": "%lld page",
        "pdf.status.pages.plural": "%lld pages",
        "ai.prompt.placeholder": "Question sur ce document…",
        "ai.send": "Demander",
        "ai.loading": "Chargement…",
        "ai.error": "Erreur : %@",
        "menu.view.autocomplete": "Autocomplétion Markdown"
    ]
    static let it: [String: String] = [
        "app.name": "Markeer",
        "menu.view": "Visualizza",
        "menu.view.settings": "Impostazioni…",
        "menu.view.fullscreen": "Schermo intero",
        "menu.view.markdown": "Markdown",
        "menu.view.rich": "Formattato",
        "menu.view.split": "Lato a lato",
        "menu.view.cycle": "Vista successiva",
        "menu.edit": "Modifica",
        "menu.format": "Formato",
        "menu.format.bold": "Grassetto",
        "menu.format.italic": "Corsivo",
        "menu.format.heading": "Intestazione",
        "menu.format.list": "Elenco puntato",
        "menu.format.numberedList": "Elenco numerato",
        "menu.format.link": "Collegamento…",
        "menu.file.exportPDF": "Esporta in PDF…",
        "status.words": "%lld parole",
        "status.chars": "%lld caratteri",
        "status.mode.markdown": "Markdown",
        "status.mode.rich": "Formattato · modificabile direttamente",
        "status.mode.split": "Lato a lato · entrambi modificabili",
        "toolbar.new": "Nuovo documento",
        "toolbar.open": "Apri",
        "toolbar.save": "Salva",
        "dialog.link.title": "Inserisci collegamento",
        "dialog.link.insert": "Inserisci",
        "dialog.link.cancel": "Annulla",
        "editor.rich.placeholder": "Inizia a scrivere…",
        "settings.title": "Impostazioni",
        "settings.ok": "OK",
        "settings.cancel": "Annulla",
        "status.encoding": "UTF-8",
        "about.credits": "Un luogo tranquillo per Markdown.\nmacOS nativo · file locali · tre viste\n\nCreato per Jeffrey.",
        "toolbar.exportPDF": "Esporta in PDF",
        "toolbar.bold": "Grassetto (⌘B)",
        "toolbar.italic": "Corsivo (⌘I)",
        "toolbar.heading": "Intestazione",
        "toolbar.list": "Elenco puntato",
        "toolbar.numberedList": "Elenco numerato (⌘⇧O)",
        "toolbar.link": "Inserisci collegamento",
        "toolbar.mode": "Visualizza",
        "toolbar.mode.tooltip": "Passa da Markdown a formattato e lato a lato (⌘⇧P)",
        "dialog.link.info": "Inserisci l'indirizzo web. Il testo selezionato diventa il collegamento.",
        "editor.source.label": "Editor Markdown",
        "error.render": "Errore di rendering",
        "error.js": "Errore JavaScript",
        "error.pdf.export": "Errore di export PDF",
        "settings.autocomplete": "Autocompletamento Markdown nell'editor sorgente",
        "settings.highlighting": "Evidenziazione sintassi per i blocchi di codice",
        "settings.frontmatter": "Mostra i metadati front-matter nella barra di stato",
        "settings.statusbar": "Mostra la barra di stato",
        "settings.inlinedollarmath": "Riconosci il calcolo inline con $...$",
        "pdf.note.add.title": "Aggiungi annotazione",
        "pdf.note.add.info": "Digita la nota da aggiungere a questa pagina.",
        "pdf.note.add.button": "Aggiungi",
        "pdf.note.cancel": "Annulla",
        "pdf.toolbar.addNote": "Aggiungi annotazione",
        "pdf.toolbar.deleteNote": "Rimuovi annotazione",
        "pdf.status.pages": "%lld pagina",
        "pdf.status.pages.plural": "%lld pagine",
        "ai.prompt.placeholder": "Domanda su questo documento…",
        "ai.send": "Chiedi",
        "ai.loading": "Caricamento…",
        "ai.error": "Errore: %@",
        "menu.view.autocomplete": "Autocompletamento Markdown"
    ]
    static let es: [String: String] = [
        "app.name": "Markeer",
        "menu.view": "Vista",
        "menu.view.settings": "Ajustes…",
        "menu.view.fullscreen": "Pantalla completa",
        "menu.view.markdown": "Markdown",
        "menu.view.rich": "Formateado",
        "menu.view.split": "Lado a lado",
        "menu.view.cycle": "Vista siguiente",
        "menu.edit": "Editar",
        "menu.format": "Formato",
        "menu.format.bold": "Negrita",
        "menu.format.italic": "Cursiva",
        "menu.format.heading": "Encabezado",
        "menu.format.list": "Lista con viñetas",
        "menu.format.numberedList": "Lista numerada",
        "menu.format.link": "Enlace…",
        "menu.file.exportPDF": "Exportar a PDF…",
        "status.words": "%lld palabras",
        "status.chars": "%lld caracteres",
        "status.mode.markdown": "Markdown",
        "status.mode.rich": "Formateado · directamente editable",
        "status.mode.split": "Lado a lado · ambos editables",
        "toolbar.new": "Documento nuevo",
        "toolbar.open": "Abrir",
        "toolbar.save": "Guardar",
        "dialog.link.title": "Insertar enlace",
        "dialog.link.insert": "Insertar",
        "dialog.link.cancel": "Cancelar",
        "editor.rich.placeholder": "Empieza a escribir…",
        "settings.title": "Ajustes",
        "settings.ok": "OK",
        "settings.cancel": "Cancelar",
        "status.encoding": "UTF-8",
        "about.credits": "Un lugar tranquilo para Markdown.\nmacOS nativo · archivos locales · tres vistas\n\nHecho para Jeffrey.",
        "toolbar.exportPDF": "Exportar a PDF",
        "toolbar.bold": "Negrita (⌘B)",
        "toolbar.italic": "Cursiva (⌘I)",
        "toolbar.heading": "Encabezado",
        "toolbar.list": "Lista con viñetas",
        "toolbar.numberedList": "Lista numerada (⌘⇧O)",
        "toolbar.link": "Insertar enlace",
        "toolbar.mode": "Vista",
        "toolbar.mode.tooltip": "Cambiar entre Markdown, formateado y lado a lado (⌘⇧P)",
        "dialog.link.info": "Introduce la dirección web. El texto seleccionado se convierte en el enlace.",
        "editor.source.label": "Editor de Markdown",
        "error.render": "Error de renderizado",
        "error.js": "Error de JavaScript",
        "error.pdf.export": "Error de exportación a PDF",
        "settings.autocomplete": "Autocompletado de Markdown en el editor de origen",
        "settings.highlighting": "Resaltado de sintaxis para bloques de código",
        "settings.frontmatter": "Mostrar metadatos front-matter en la barra de estado",
        "settings.statusbar": "Mostrar la barra de estado",
        "settings.inlinedollarmath": "Reconocer matemáticas inline con $...$",
        "pdf.note.add.title": "Añadir anotación",
        "pdf.note.add.info": "Escribe la nota que se añadirá a esta página.",
        "pdf.note.add.button": "Añadir",
        "pdf.note.cancel": "Cancelar",
        "pdf.toolbar.addNote": "Añadir anotación",
        "pdf.toolbar.deleteNote": "Eliminar anotación",
        "pdf.status.pages": "%lld página",
        "pdf.status.pages.plural": "%lld páginas",
        "ai.prompt.placeholder": "Pregunta sobre este documento…",
        "ai.send": "Preguntar",
        "ai.loading": "Cargando…",
        "ai.error": "Error: %@",
        "menu.view.autocomplete": "Autocompletado de Markdown"
    ]

    private static var bundles: [String: [String: String]] = [
        "nl": nl, "en": en, "de": de, "fr": fr, "it": it, "es": es
    ]

    /// Bundel voor een taalcodes; geeft nil terug als de taal niet wordt ondersteund.
    static func bundle(for code: String) -> [String: String]? {
        bundles[code.lowercased()]
    }

    /// Bepaal de te gebruiken taalcodes uit een lijst systeemtaalvoorkeuren.
    /// De eerste ondersteunde code wint; anders Engels (fallback).
    static func resolveLanguage(fromPreferences prefs: [String]) -> String {
        for raw in prefs {
            // "nl-BE", "nl_NL", "nld" → "nl".
            let dashParts = raw.split(separator: "-")
            let base: String
            if dashParts.count > 1 {
                base = String(dashParts.first!)
            } else if raw.contains("_") {
                base = String(raw.split(separator: "_").first!)
            } else {
                base = raw
            }
            if bundle(for: base) != nil { return base }
        }
        return "en"
    }

    /// Huidige taalcodes: systeemtaal (of test-override), anders Engels.
    static func currentLanguage() -> String {
        if let override = overrideLanguage { return override }
        let prefs = Locale.preferredLanguages
        return resolveLanguage(fromPreferences: prefs)
    }

    /// Vertaal een key. Fallback: huidige taal → Engels → de key zelf.
    /// Zonder args wordt het template rechtstreeks teruggegeven; met args wordt
    /// `String(format:locale:)` gebruikt (voor plurals/percentages).
    static func string(_ key: String) -> String {
        let lang = currentLanguage()
        return bundle(for: lang)?[key] ?? en[key] ?? key
    }

    /// Vertaal een key met invoegbare argumenten (bv. "@lld woorden").
    @_disfavoredOverload
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let lang = currentLanguage()
        let template = bundle(for: lang)?[key] ?? en[key] ?? key
        return String(format: template, locale: Locale(identifier: lang), arguments: args)
    }

    /// Alleen voor tests: forceer een taal tijdelijk (beïnvloedt currentLanguage).
    static var overrideLanguage: String?
    static func currentLanguageIgnoringOverride() -> String { currentLanguage() }
}
