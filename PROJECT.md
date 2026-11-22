# Markeer: project notes

## Architecture

A native macOS document application. `MarkdownDocument` owns UTF-8 text and uses `NSDocument` for opening, saving and autosave. `EditorWindowController` combines a plain `NSTextView` source editor with an editable `WKWebView`.

`MarkeerPDFDocument` opens PDF files in a three-panel window: page thumbnails, PDFKit view, and an Ask AI panel. The Ask AI panel asks a local Ollama model (default `llama3.2:1b`, `http://localhost:11434`) about the document; the context is the current page's text (falling back to the whole document), truncated to 12000 characters. All requests stay on the local network; when Ollama is unreachable the app shows a Dutch error in the panel.

The source text is rendered with vendored cmark-gfm. Rendered blocks retain their original Markdown. The formatted editor converts changed blocks back through Turndown and preserves untouched blocks and reference definitions. Revision identifiers prevent stale editor messages from replacing more recent source edits.

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

The automated suite covers rendering, document encodings, source-mode numbered-list edits, formatted text conversion, preservation of existing blocks, table and checkbox edits, relative images, safe code fences, native bridge messages, and Jekyll front-matter recognition, parsing and byte-exact preservation through rich edits. The AskAI suite (a live round-trip against local Ollama plus a connection-error check) runs when Ollama is reachable and is skipped otherwise.

Native window checks cover source/formatted/split views, formatting, undo, tasks, table edits, save/reopen, undo after saving, and the numbered-list button in both editors. The macOS unified log is unavailable inside the command sandbox, so a complete app-log review is not claimed. The legacy optional headless WebKit checks are separate from the passing Swift and DOM suites.

## Current limitations

No math rendering, code syntax highlighting, Markdown auto-completion, or full rendering-preferences interface. Front matter is recognized and preserved but not editable in the formatted editor (source mode only). Raw HTML is shown literally. Find operates in the source editor. Interface labels are currently Dutch.