import Foundation

/// Gecentraliseerde, opgeslagen voorkeuren voor Markeer. Pure logica zodat
/// defaults en persistentie unit-testbaar zijn zonder een UI. De weergave-
/// vensters lezen hieruit; preview-updates markeren documenten nooit als
/// gewijzigd en wijzigen geen bronbestanden.
struct Preferences: Codable, Equatable {
    /// Markdown-autocomplete in de broneditor (lijst, delimiters, links).
    var autocompleteEnabled: Bool
    /// Syntaxhighlighting voor fenced codeblokken (highlight.js).
    var codeHighlightingEnabled: Bool
    /// Toon Jekyll front-matter-metadata in de statusbalk.
    var showFrontMatter: Bool
    /// Voortgangs-/statusbalk onderaan het venster.
    var showStatusBar: Bool
    /// Inline-math met enkele dollar ($...$) herkennen. Uitgeschakeld houdt
    /// gewone dollarbedragen (bv $5) intact; $$...$$, \[..\] en \(..\) werken altijd.
    var inlineDollarMath: Bool

    static let `default` = Preferences(
        autocompleteEnabled: true,
        codeHighlightingEnabled: true,
        showFrontMatter: true,
        showStatusBar: true,
        inlineDollarMath: false
    )

    private static let key = "Markeer.preferences"

    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return .default }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
