import Foundation
import AppKit
import ApplicationServices

class PermissionsManager: ObservableObject {
    @Published var screenRecordingAllowed: Bool = false
    @Published var accessibilityAllowed: Bool = false
    private var timer: Timer?

    var allPermissionsGranted: Bool { screenRecordingAllowed && accessibilityAllowed }
    
    init() {
        checkPermissions()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }
    
    func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let access = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let screen = CGPreflightScreenCaptureAccess()
        
        DispatchQueue.main.async {
            if self.accessibilityAllowed != access { self.accessibilityAllowed = access }
            if self.screenRecordingAllowed != screen { self.screenRecordingAllowed = screen }
        }
    }
    
    func triggerSystemPermissionPopup() {
        // Richiesta esplicita per screen recording
        _ = CGRequestScreenCaptureAccess()
        
        // Richiesta per accessibility (apre la UI di sistema che invita ad abilitare)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
