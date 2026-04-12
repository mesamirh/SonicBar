import AppKit
import SwiftUI

// Proven approach: lightweight timer polling NSEvent.mouseLocation
// This is the exact same technique used in the original working code
// and by apps like NotchNook. It requires zero permissions.
// At 20Hz (0.05s), it uses negligible CPU — just one rect.contains() check per tick.
class NotchTracker {
    private let hoverState = HoverState.shared
    private var timer: Timer?
    
    // Pre-calculated zones
    private var triggerRect: NSRect = .zero
    private var expandedRect: NSRect = .zero
    
    init() {
        recalculateZones()
        startTracking()
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(displayChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func displayChanged() {
        recalculateZones()
    }
    
    private func recalculateZones() {
        guard let screen = NSScreen.builtIn else { return }
        
        let notchH = screen.notchHeight
        let notchW = screen.notchWidth
        
        let height: CGFloat = notchH > 0 ? notchH : 32
        hoverState.notchHeight = height
        
        let midX = screen.frame.midX
        let maxY = screen.frame.maxY
        
        // Trigger: centered around notch, slightly wider for easy targeting
        let triggerW: CGFloat = max(notchW, 200) + 10
        triggerRect = NSRect(
            x: midX - triggerW / 2,
            y: maxY - height,
            width: triggerW,
            height: height
        )
        
        // Expanded: covers the full player area when visible
        expandedRect = NSRect(
            x: midX - 210,
            y: maxY - 420,
            width: 420,
            height: 420
        )
    }
    
    private func startTracking() {
        // 20Hz — proven lightweight, same as original working code
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
    }
    
    private func evaluate() {
        let loc = NSEvent.mouseLocation
        let state = hoverState.state
        
        // Don't interfere when user is interacting (menu/playlist open)
        if state == .interacting { return }
        
        let isInTrigger = triggerRect.contains(loc)
        let isInExpanded = state != .hidden && expandedRect.contains(loc)
        let shouldShow = isInTrigger || isInExpanded
        let isShowing = state != .hidden
        
        // Only act on transitions
        if shouldShow == isShowing { return }
        
        DispatchQueue.main.async {
            if shouldShow {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    self.hoverState.state = .hovered
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    self.hoverState.state = .hidden
                }
            }
            
            // Toggle mouse passthrough on the panel
            if let window = NSApplication.shared.windows.first(where: { $0 is NotchPanel }) {
                window.ignoresMouseEvents = !shouldShow
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
