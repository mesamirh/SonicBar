import SwiftUI
import AppKit

@main
struct SonicBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var islandWindow: NSPanel!
    let audioPlayer = AudioPlayer()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let notchView = ContentView().environmentObject(audioPlayer)
        let hostingView = NSHostingView(rootView: notchView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let notchWidth: CGFloat = 420
        let notchHeight: CGFloat = 420
        
        // Center at top of screen
        let windowRect = NSRect(
            x: screenRect.midX - (notchWidth / 2),
            y: screenRect.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        islandWindow = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        islandWindow.isOpaque = false
        islandWindow.hasShadow = false
        islandWindow.backgroundColor = .clear
        islandWindow.level = .popUpMenu // Float over everything
        islandWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        islandWindow.contentView = hostingView
        
        islandWindow.makeKeyAndOrderFront(nil)
    }
}
