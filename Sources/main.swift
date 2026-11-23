import AppKit

final class AppDelegate:NSObject,NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps:true)
        if NSDocumentController.shared.documents.isEmpty { NSDocumentController.shared.newDocument(nil) }
    }
    func applicationShouldOpenUntitledFile(_ sender:NSApplication)->Bool {true}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    var editor:EditorWindowController? { NSApp.keyWindow?.windowController as? EditorWindowController }
    @objc func cycle(_ sender:Any?) {editor?.cycleMode(sender)}
    @objc func source(_ sender:Any?) {editor?.sourceMode(sender)}
    @objc func rich(_ sender:Any?) {editor?.richMode(sender)}
    @objc func split(_ sender:Any?) {editor?.splitMode(sender)}
    @objc func bold(_ sender:Any?) {editor?.bold()}
    @objc func italic(_ sender:Any?) {editor?.italic()}
    @objc func heading(_ sender:Any?) {editor?.heading()}
    @objc func list(_ sender:Any?) {editor?.list()}
    @objc func numberedList(_ sender:Any?) {editor?.numberedList()}
    @objc func link(_ sender:Any?) {editor?.link()}
    @objc func exportPDF(_ sender:Any?) {editor?.exportPDF()}
    @objc func showSettings(_ sender:Any?) {
        // Elke openstaande editor moet nieuwe voorkeuren direct oppakken.
        SettingsWindowController.shared.setOnApply { prefs in
            for window in NSApp.windows {
                if let controller = window.windowController as? EditorWindowController {
                    controller.applyPreferences(prefs)
                }
            }
        }
        SettingsWindowController.shared.showWindow(sender)
        SettingsWindowController.shared.window?.makeKeyAndOrderFront(sender)
    }
    @objc func about(_ sender:Any?) {
        NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Markeer",.applicationVersion:appVersion(),.credits:NSAttributedString(string:L10n.string("about.credits"))])
    }
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
let bar=NSMenu();app.mainMenu=bar
func menu(_ title:String)->NSMenu {
    let item=NSMenuItem(title:title,action:nil,keyEquivalent:"");bar.addItem(item)
    let menu=NSMenu(title:title);item.submenu=menu;return menu
}
@discardableResult
func item(_ menu:NSMenu,_ title:String,_ action:Selector?,_ key:String="",_ modifiers:NSEvent.ModifierFlags = .command,_ target:AnyObject?=nil)->NSMenuItem {
    let item=NSMenuItem(title:title,action:action,keyEquivalent:key)
    item.keyEquivalentModifierMask=modifiers;item.target=target;menu.addItem(item);return item
}
let application=menu(L10n.string("app.name"))
item(application,"Over Markeer",#selector(AppDelegate.about(_:)),"",.command,delegate)
application.addItem(.separator())
let services=NSMenu(title:"Voorzieningen");let servicesItem=item(application,"Voorzieningen",nil);servicesItem.submenu=services;app.servicesMenu=services
application.addItem(.separator())
item(application,"Verberg Markeer",#selector(NSApplication.hide(_:)),"h")
item(application,"Verberg andere",#selector(NSApplication.hideOtherApplications(_:)),"h",[.command,.option])
item(application,"Toon alles",#selector(NSApplication.unhideAllApplications(_:)))
application.addItem(.separator())
item(application,"Stop Markeer",#selector(NSApplication.terminate(_:)),"q")
let file=menu("Bestand")
item(file,"Nieuw",#selector(NSDocumentController.newDocument(_:)),"n",.command,NSDocumentController.shared)
item(file,"Open…",#selector(NSDocumentController.openDocument(_:)),"o",.command,NSDocumentController.shared)
let recent=NSMenu(title:"Open recente bestanden")
recent.perform(NSSelectorFromString("_setMenuName:"),with:"NSRecentDocumentsMenu")
item(file,"Open recente bestanden",nil).submenu=recent
file.addItem(.separator())
item(file,"Sluit",#selector(NSWindow.performClose(_:)),"w")
item(file,"Bewaar",#selector(NSDocument.save(_:)),"s")
item(file,"Bewaar als…",#selector(NSDocument.saveAs(_:)),"s",[.command,.shift])
item(file,"Herstel naar bewaarde versie…",#selector(NSDocument.revertToSaved(_:)))
file.addItem(.separator())
item(file,L10n.string("menu.file.exportPDF"),#selector(AppDelegate.exportPDF(_:)),"p",[.command,.shift],delegate)
let edit=menu(L10n.string("menu.edit"))
item(edit,"Maak ongedaan",Selector(("undo:")),"z")
item(edit,"Opnieuw",Selector(("redo:")),"z",[.command,.shift])
edit.addItem(.separator())
item(edit,"Knip",#selector(NSText.cut(_:)),"x")
item(edit,"Kopieer",#selector(NSText.copy(_:)),"c")
item(edit,"Plak",#selector(NSText.paste(_:)),"v")
item(edit,"Selecteer alles",#selector(NSText.selectAll(_:)),"a")
edit.addItem(.separator())
let find=item(edit,"Zoek…",#selector(NSTextView.performFindPanelAction(_:)),"f");find.tag=Int(NSFindPanelAction.showFindPanel.rawValue)
let format=menu(L10n.string("menu.format"))
item(format,L10n.string("menu.format.bold"),#selector(AppDelegate.bold(_:)),"b",.command,delegate)
item(format,L10n.string("menu.format.italic"),#selector(AppDelegate.italic(_:)),"i",.command,delegate)
item(format,L10n.string("menu.format.heading"),#selector(AppDelegate.heading(_:)),"h",[.command,.shift],delegate)
item(format,L10n.string("menu.format.list"),#selector(AppDelegate.list(_:)),"l",[.command,.shift],delegate)
item(format,L10n.string("menu.format.numberedList"),#selector(AppDelegate.numberedList(_:)),"o",[.command,.shift],delegate)
item(format,L10n.string("menu.format.link"),#selector(AppDelegate.link(_:)),"k",.command,delegate)
let view=menu(L10n.string("menu.view"))
item(view,L10n.string("menu.view.cycle"),#selector(AppDelegate.cycle(_:)),"p",[.command,.shift],delegate)
view.addItem(.separator())
item(view,L10n.string("menu.view.markdown"),#selector(AppDelegate.source(_:)),"1",.command,delegate)
item(view,L10n.string("menu.view.rich"),#selector(AppDelegate.rich(_:)),"2",.command,delegate)
item(view,L10n.string("menu.view.split"),#selector(AppDelegate.split(_:)),"3",.command,delegate)
view.addItem(.separator())
item(view,L10n.string("menu.view.settings"),#selector(AppDelegate.showSettings(_:)),",",.command,delegate)
view.addItem(.separator())
item(view,L10n.string("menu.view.fullscreen"),#selector(NSWindow.toggleFullScreen(_:)),"f",[.command,.control])
let windows=menu("Venster");app.windowsMenu=windows
item(windows,"Minimaliseer",#selector(NSWindow.performMiniaturize(_:)),"m")
item(windows,"Zoom",#selector(NSWindow.performZoom(_:)))
windows.addItem(.separator())
item(windows,"Breng alles naar voren",#selector(NSApplication.arrangeInFront(_:)))
app.run()
