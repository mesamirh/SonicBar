import SwiftUI
import AppKit
import Combine

@main
struct SonicBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.isMovableByWindowBackground = false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var islandWindow: NotchPanel!
    let audioPlayer = AudioPlayer()
    let hoverState = HoverState.shared
    var tracker: NotchTracker?
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let notchView = ContentView()
            .environmentObject(audioPlayer)
            .environmentObject(hoverState)
            
        let hostingView = NSHostingView(rootView: notchView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Determine if already connected
        let typeStr = UserDefaults.standard.string(forKey: "ActiveServerType") ?? ServerType.subsonic.rawValue
        let isConnected: Bool
        if typeStr == ServerType.jellyfin.rawValue {
            isConnected = !(UserDefaults.standard.string(forKey: "JellyfinURL") ?? "").isEmpty
        } else if typeStr == ServerType.local.rawValue {
            isConnected = !(UserDefaults.standard.string(forKey: "LocalMusicPaths") ?? "").isEmpty
        } else {
            isConnected = !(UserDefaults.standard.string(forKey: "SubsonicURL") ?? "").isEmpty
        }
        
        // Use built-in screen for accurate placement
        let screen = NSScreen.builtIn ?? NSScreen.main ?? NSScreen.screens.first!
        let panelW: CGFloat = 420
        let panelH: CGFloat = 420
        
        let windowRect: NSRect
        if isConnected {
            // Notch position: centered at top
            windowRect = NSRect(
                x: screen.frame.midX - panelW / 2,
                y: screen.frame.maxY - panelH,
                width: panelW,
                height: panelH
            )
        } else {
            // Setup wizard: centered on screen
            windowRect = NSRect(
                x: screen.frame.midX - panelW / 2,
                y: screen.frame.midY - panelH / 2,
                width: panelW,
                height: panelH
            )
        }
        
        // KEY: .nonactivatingPanel allows hover to work without stealing focus
        islandWindow = NotchPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        islandWindow.isOpaque = false
        islandWindow.hasShadow = false
        islandWindow.backgroundColor = .clear
        // KEY: .popUpMenu level ensures we float above everything just like the original
        islandWindow.level = .popUpMenu
        islandWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        islandWindow.contentView = hostingView
        
        // Start collapsed: don't capture clicks when hidden
        if isConnected {
            islandWindow.ignoresMouseEvents = true
        }
        
        islandWindow.makeKeyAndOrderFront(nil)
        
        // Initialize tracker AFTER window is set up
        self.tracker = NotchTracker()
        
        // Movement lock toggle
        hoverState.$isLockedToNotch
            .sink { [weak self] isLocked in
                self?.islandWindow.isMovableByWindowBackground = !isLocked
            }
            .store(in: &cancellables)
        
        if !isConnected {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(transitionToNotch), name: NSNotification.Name("ConnectedToServer"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsToggle(_:)), name: NSNotification.Name("ToggleSettingsPosition"), object: nil)
    }
    
    @objc func handleSettingsToggle(_ notification: Notification) {
        let isOpening = notification.object as? Bool ?? false
        let screen = NSScreen.builtIn ?? NSScreen.main ?? NSScreen.screens.first!
        let panelW: CGFloat = 420
        let panelH: CGFloat = 420
        
        let targetRect: NSRect
        if isOpening {
            targetRect = NSRect(
                x: screen.frame.midX - panelW / 2,
                y: screen.frame.midY - panelH / 2,
                width: panelW,
                height: panelH
            )
        } else {
            targetRect = NSRect(
                x: screen.frame.midX - panelW / 2,
                y: screen.frame.maxY - panelH,
                width: panelW,
                height: panelH
            )
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            islandWindow.animator().setFrame(targetRect, display: true)
        }
    }
    
    @objc func transitionToNotch() {
        let screen = NSScreen.builtIn ?? NSScreen.main ?? NSScreen.screens.first!
        let panelW: CGFloat = 420
        let panelH: CGFloat = 420
        
        let targetRect = NSRect(
            x: screen.frame.midX - panelW / 2,
            y: screen.frame.maxY - panelH,
            width: panelW,
            height: panelH
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.8
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            islandWindow.animator().setFrame(targetRect, display: true)
        }
    }
}
