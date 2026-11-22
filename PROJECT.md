# Markeer: project notes

## Architecture

A native macOS document application. `MarkdownDocument` owns UTF-8 text and uses `NSDocument` for opening, saving and autosave. `EditorWindowController` combines a plain `NSTextView` source editor with an editable `WKWebView`.

`MarkeerPDFDocument` opens PDF files in a three-panel window: page thumbnails, PDFKit view, and an Ask AI panel. The Ask AI panel asks a local Ollama model (default `llama3.2:1b`, `http://localhost:11434`) about the document; the context is the current page's text (falling back to the whole document), truncated to 12000 characters. All requests stay on the local network; when Ollama is unreachable the app shows a Dutch error in the panel.

The source text is rendered with vendored cmark-gfm. Rendered blocks retain their original Markdown. The formatted editor converts changed blocks back through Turndown and preserves untouched blocks and reference definitions. Revision identifiers prevent stale editor messages from replacing more recent source edits.

Fenced code blocks are highlighted offline with the bundled highlight.js (all common languages and aliases), using the bundled GitHub light and dark themes selected via `prefers-color-scheme`. Unknown or missing language identifiers fall back to plain code. Highlighting only wraps the code in spans; the code text and the `language-*` class are unchanged, so the Turndown `safeCodeFence` rule still round-trips edited and untouched blocks byte-for-byte and language fences are preserved.

The source editor offers Markdown auto-completion as pure, unit-tested logic in `MarkdownEditing`: list continuation (Enter on a non-empty list item repeats the same marker and indentation; an empty item stops the list), selection wrap for inline delimiters (`*`, `**`, `_`, `` ` ``, `~~` wrap the selected text), and link completion (typing `(` right after `]` inserts `https://`). The logic is pure (text + caret + selection in, insertion + caret out), so caret position, selection, Unicode and ordinary text are covered by automated tests without a UI. It is enabled by default and toggled from the Weergave menu, persisted in `UserDefaults`. IME composition is not intercepted (the editor falls back to normal input while marked text is active), so CJK/emoji composition is unaffected. Rich-mode editing is intentionally left to the existing formatting toolbar.

Extended syntax (MacDown-pariteit subset): **footnotes** are parsed by cmark-gfm (`CMARK_OPT_FOOTNOTES`) — a `[^n]` reference renders as a `<sup class="footnote-ref">` and the definition becomes an endnote `<section class="footnotes">`; the formatted editor converts `footnote-ref` back to `[^n]` and preserves definitions. **Highlight** `==text==` is converted to `<mark>` by a code-aware pre-pass (fenced blocks and inline code are left untouched), and the editor converts `<mark>` back to `==text==`. Both round-trip through the rich editor. Underline uses raw `<u>` (shown literally, like other raw HTML); SmartyPants, intra-word emphasis configuration and full footnotes-in-body editing are not included (see limitations).

Native settings: a Settings window (Weergave ▸ Instellingen…, ⌘,) edits persisted preferences in `Preferences` (UserDefaults): Markdown auto-completion, code syntax highlighting, front-matter metadata in the status bar, and the status bar itself. Preferences are read from a single shared source, so they are consistent across all open windows; toggling applies live to every editor without marking documents as modified and without touching source files. The settings logic is pure and unit-tested (defaults + persistence).

Localization: all user-facing UI strings (menus, toolbar, tooltips, accessibility labels, status bar incl. plurals, the link dialog, errors and the About panel) come from a central `L10n` layer with in-process, offline bundles for NL (default/kept), EN, DE, FR, IT and ES. The macOS system language is followed; unsupported languages fall back to English, and missing keys fall back predictably (current language → English → the key itself). Source Markdown and user content are never translated (the renderer is language-agnostic). Language resolution, fallback and translation are pure and unit-tested.

### Maintaining new labels and translations (workflow)

1. **Author the key in English first.** `L10n.en` is the authoritative vocabulary: add the new key there with a `String(format:)`-compatible template (`%@` for text, `%lld`/`%d` for numbers — used for plurals).
2. **Translate into every supported language** (`nl`, `de`, `fr`, `it`, `es`). Every language must contain exactly the same key set as English — this is enforced automatically.
3. **Use the key in code** via `L10n.string("key")` or `L10n.string("key", arg1, arg2)`. Never hard-code user-facing text in Swift or the bundled editor HTML/JS.
4. **Plurals**: keep the singular and plural forms as separate keys (e.g. `pdf.status.pages` / `pdf.status.pages.plural`) and pick at the call site; do not try to derive plurals from the template.
5. **Accessibility and keyboard**: set `setAccessibilityLabel(L10n.string(...))` on controls and keep existing key equivalents — a new label must not break VoiceOver or keyboard navigation.
6. **Run the suite.** `Tests/run.sh` includes an automatic completeness check that fails if any language's key set differs from English's or if any translation is empty, plus per-language resolution, fallback, plural and never-translate-content checks. This is the gate that keeps all six languages in parity.

Test documents are saved and reopened without translation or Markdown corruption because the renderer is language-agnostic; only the surrounding UI chrome is localized.

A Jekyll YAML front-matter block at the very start of a document is recognized (conservatively: exact `---` on line one, exact closing `---`, no leading blank line) and excluded from Markdown rendering. The block's source text is carried verbatim through the render payload and the formatted editor prepends it unchanged on serialize, so rich edits to the body never alter the front matter. The status bar shows a short metadata preview (first entries) when present.

Saving updates relative image URLs without replacing the editor DOM. This preserves WebKit's undo history across the initial save and subsequent saves.

The numbered-list toolbar action uses `insertOrderedList` in the formatted editor. In source mode, it edits whole selected lines, handles UTF-16 text-selection offsets, replaces existing list markers, and leaves unselected lines alone.

## Build and packaging

- Target: Apple Silicon, macOS 13 or later.
- Build: `build.sh`; complete automated checks: `Tests/run.sh`.
- Build products: `dist/`; intermediate files and test dependencies: `.build/`.
- Runtime dependencies are bundled; the app does not need Node.js or Python.
- Sign app bundles in a temporary directory outside iCloud, then package them. Finder metadata in an iCloud folder can invalidate signing checks on the unpacked copy.
- Releases are locally ad-hoc signed. Apple Developer signing and notarization are not included.

## Verification

The automated suite covers rendering, document encodings, source-mode numbered-list edits, formatted text conversion, preservation of existing blocks, table and checkbox edits, relative images, safe code fences, code syntax-highlighting round-trips (known, unknown and missing language), source-mode Markdown auto-completion (list continuation incl. indentation, empty-item stop and Unicode; delimiter wrap; link completion; no-op on ordinary text), footnotes (reference → `<sup>`, definition → endnote section, source preservation) and `==highlight==` → `<mark>` (incl. fenced/inline-code protection), native bridge messages, Preferences defaults and persistence, localization (language resolution, fallback, translation, and that Markdown content is never translated), and Jekyll front-matter recognition, parsing and byte-exact preservation through rich edits. The AskAI suite (a live round-trip against local Ollama plus a connection-error check) runs when Ollama is reachable and is skipped otherwise.

Native window checks cover source/formatted/split views, formatting, undo, tasks, table edits, save/reopen, undo after saving, and the numbered-list button in both editors. The macOS unified log is unavailable inside the command sandbox, so a complete app-log review is not claimed. The legacy optional headless WebKit checks are separate from the passing Swift and DOM suites.

## Current limitations

No math rendering, Markdown auto-completion in the rich (formatted) editor, SmartyPants, intra-word emphasis configuration, or per-option syntax toggles beyond the current settings (auto-completion, highlighting, front-matter display, status bar). Source-mode auto-completion is limited to list continuation, delimiter wrap and link completion (see above). Footnotes and `==highlight==` are supported (see extended syntax); underline is raw `<u>` and shown literally. Front matter is recognized and preserved but not editable in the formatted editor (source mode only). Raw HTML is shown literally. Find operates in the source editor. Interface labels are localized via `L10n` for NL/EN/DE/FR/IT/ES (system language, English fallback); some minor strings (e.g. the File/Venster menu titles and a few PDF labels) remain single-language until a follow-up. Find operates in the source editor.