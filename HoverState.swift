import SwiftUI

enum NotchState: String {
    case hidden      // Totally collapsed/small bar
    case hovered     // Mouse is over notch, player matches expanded size
    case interacting // User is interacting (playlist open, etc.) -> don't hide
}

class HoverState: ObservableObject {
    static let shared = HoverState()
    @Published var state: NotchState = .hidden
    @Published var notchHeight: CGFloat = 34
    @Published var isLockedToNotch: Bool = true
    
    var isHovered: Bool {
        return state != .hidden
    }
}
