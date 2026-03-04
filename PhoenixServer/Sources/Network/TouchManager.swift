//
//  TouchManager.swift
//  PhoenixServer
//
//  Receives touch events via UDP from Android tablet
//  Converts coordinates and injects real mouse events using CoreGraphics (CGEvent)
//  Works with virtual monitor (BetterDisplay)
//  Fixed for Intel Mac alignment and Android 4.0 Little Endian
//

import Foundation
import Network
import CoreGraphics

protocol TouchManagerDelegate: AnyObject {
    func touchManager(_ manager: TouchManager, didReceiveTouch touch: TouchEvent)
    func touchManager(_ manager: TouchManager, didChangeConnectionState connected: Bool)
}

/// Touch event structure for Android tablet communication
struct TouchEvent {
    var x: UInt16        // X coordinate (0-1023)
    var y: UInt16        // Y coordinate (0-767)
    var action: UInt8    // 1=down, 2=move, 3=up
    var pressure: UInt8  // Pressure (0-255)
    var padding: UInt8   // Unused padding
    var timestamp: UInt32 // Timestamp in ms
    
    static var size: Int { return 12 }
}

class TouchManager {
    weak var delegate: TouchManagerDelegate?
    
    // Configuration
    static let touchPort: UInt16 = 5555
    
    // Display configuration
    var captureWidth: Int = 1024
    var captureHeight: Int = 768
    
    private var virtualDisplayBounds: CGRect = .zero
    private var virtualDisplayID: CGDirectDisplayID = 0
    
    // Network
    private var listener: NWListener?
    private var currentConnection: NWConnection?
    private let receiveQueue = DispatchQueue(label: "phoenix.touch", qos: .userInteractive)
    
    // State
    private(set) var isListening = false
    private var eventSource: CGEventSource?
    
    init() {
        findVirtualDisplay()
    }
    
    /// Cerca il monitor virtuale basandosi sui dati di BetterDisplay (ID: 4128835)
    private func findVirtualDisplay() {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        let result = CGGetOnlineDisplayList(16, &displays, &displayCount)
        
        if result == .success {
            for i in 0..<Int(displayCount) {
                let displayID = displays[i]
                let bounds = CGDisplayBounds(displayID)
                
                // Cerchiamo un display che NON sia il principale.
                // Il tuo report indica un ID 4128835 o simili.
                if displayID != CGMainDisplayID() {
                    // Verifichiamo che abbia le dimensioni tipiche del tuo setup virtuale
                    // (Accettiamo 1024 o 1440 come larghezza base)
                    if bounds.width == 1024 || bounds.width == 1440 {
                        virtualDisplayID = displayID
                        virtualDisplayBounds = bounds
                        print("✅ TouchManager: Monitor Virtuale agganciato! ID: \(displayID), Bounds: \(virtualDisplayBounds)")
                        return
                    }
                }
            }
        }
        
        // Fallback al monitor principale se non trova il virtuale
        virtualDisplayID = CGMainDisplayID()
        virtualDisplayBounds = CGDisplayBounds(virtualDisplayID)
        print("⚠️ TouchManager: Monitor virtuale non trovato, uso il principale: \(virtualDisplayBounds)")
    }
    
    func startListening() throws {
        guard !isListening else { return }
        eventSource = CGEventSource(stateID: .hidSystemState)
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: TouchManager.touchPort)!)
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("🚀 TouchManager in ascolto sulla porta \(TouchManager.touchPort)")
                DispatchQueue.main.async {
                    self?.isListening = true
                    self?.delegate?.touchManager(self!, didChangeConnectionState: true)
                }
            case .failed(let error):
                print("❌ TouchManager Errore: \(error)")
                self?.stopListening()
            default: break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener?.start(queue: receiveQueue)
    }
    
    func stopListening() {
        listener?.cancel()
        currentConnection?.cancel()
        isListening = false
        print("🛑 TouchManager fermato")
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        currentConnection?.cancel()
        currentConnection = connection
        connection.start(queue: receiveQueue)
        receiveData(from: connection)
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self = self else { return }
            if let data = data, data.count >= TouchEvent.size {
                self.processTouchData(data)
            }
            if error == nil && self.isListening {
                self.receiveData(from: connection)
            }
        }
    }
    
    private func processTouchData(_ data: Data) {
        guard data.count >= TouchEvent.size else { return }
        
        // FIX: Caricamento unaligned per Intel + Conversione Little Endian per Android 4.0
        let touchEvent = data.withUnsafeBytes { ptr -> TouchEvent in
            let x = ptr.loadUnaligned(fromByteOffset: 0, as: UInt16.self).littleEndian
            let y = ptr.loadUnaligned(fromByteOffset: 2, as: UInt16.self).littleEndian
            let action = ptr.loadUnaligned(fromByteOffset: 4, as: UInt8.self)
            let pressure = ptr.loadUnaligned(fromByteOffset: 5, as: UInt8.self)
            let padding = ptr.loadUnaligned(fromByteOffset: 6, as: UInt8.self)
            let timestamp = ptr.loadUnaligned(fromByteOffset: 7, as: UInt32.self).littleEndian
            
            return TouchEvent(x: x, y: y, action: action, pressure: pressure, padding: padding, timestamp: timestamp)
        }
        
        let macPoint = mapTabletToMac(x: touchEvent.x, y: touchEvent.y)
        injectMouseEvent(action: touchEvent.action, point: macPoint, pressure: touchEvent.pressure)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.touchManager(self, didReceiveTouch: touchEvent)
        }
    }
    
    private func mapTabletToMac(x: UInt16, y: UInt16) -> CGPoint {
        // Normalizzazione 0.0 - 1.0 (L'input del tablet è 1024x768)
        let normalizedX = Double(x) / Double(captureWidth - 1)
        let normalizedY = Double(y) / Double(captureHeight - 1)
        
        // Mappatura sulle coordinate globali del display scelto
        let globalX = virtualDisplayBounds.origin.x + (normalizedX * virtualDisplayBounds.width)
        let globalY = virtualDisplayBounds.origin.y + (normalizedY * virtualDisplayBounds.height)
        
        return CGPoint(x: globalX, y: globalY)
    }
    
    private func injectMouseEvent(action: UInt8, point: CGPoint, pressure: UInt8) {
        guard let source = eventSource else { return }
        
        // Clamp per sicurezza entro i bordi del monitor
        let clampedX = max(virtualDisplayBounds.minX, min(virtualDisplayBounds.maxX - 1, point.x))
        let clampedY = max(virtualDisplayBounds.minY, min(virtualDisplayBounds.maxY - 1, point.y))
        let clampedPoint = CGPoint(x: clampedX, y: clampedY)
        
        let type: CGEventType
        switch action {
        case 1: type = .leftMouseDown
        case 2: type = .leftMouseDragged
        case 3: type = .leftMouseUp
        default: return
        }
        
        if let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: clampedPoint, mouseButton: .left) {
            let normalizedPressure = Double(pressure) / 255.0
            event.setDoubleValueField(.mouseEventPressure, value: normalizedPressure)
            event.post(tap: .cghidEventTap)
        }
    }
    
    func refreshDisplayBounds() {
        if virtualDisplayID != 0 {
            virtualDisplayBounds = CGDisplayBounds(virtualDisplayID)
            print("🔄 Display bounds aggiornati: \(virtualDisplayBounds)")
        } else {
            findVirtualDisplay()
        }
    }
    
    deinit {
        stopListening()
    }
}
