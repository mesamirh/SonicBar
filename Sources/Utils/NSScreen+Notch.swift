import AppKit

extension NSScreen {
    // Find built-in screen (usually has the notch)
    static var builtIn: NSScreen? {
        return NSScreen.screens.first { screen in
            // Built-in displays have a specific device description key
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let screenNumber = screen.deviceDescription[key] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(screenNumber) != 0
        } ?? NSScreen.screens.first // Fallback to primary
    }
    
    var notchHeight: CGFloat {
        if #available(macOS 12.0, *) {
            return safeAreaInsets.top
        }
        return 0
    }
    
    var hasNotch: Bool {
        return notchHeight > 0
    }
    
    // Estimate notch width from safe area
    var notchWidth: CGFloat {
        guard #available(macOS 12.0, *), hasNotch else { return 0 }
        
        let screenWidth = frame.width
        let leftWidth = auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = auxiliaryTopRightArea?.width ?? 0
        
        let width = screenWidth - leftWidth - rightWidth
        // Fallback for non-standard notch widths
        return (width > 50 && width < 400) ? width : 180
    }
}
