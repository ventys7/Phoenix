import Foundation
import Combine
import QuartzCore
import CoreMedia

enum ServerState: String {
    case idle = "Idle"
    case starting = "Starting..."
    case streaming = "Streaming"
    case stopping = "Stopping..."
}

class ServerManager: ObservableObject {
    @Published var serverState: ServerState = .idle
    @Published var currentPIN: String = "----"
    @Published var fps: Double = 0
    @Published var tabletConnected: Bool = false
    
    @Published var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID()
    
    let tabletIP = "192.168.1.11"
    let width = 1024
    let height = 768
    let targetFPS = 30
    
    private var displaySource: DisplaySource?
    private var videoEncoder: GPUVideoEncoder?
    private var touchManager: TouchManager?
    private var udpStreamer: UDPStreamer?
    private var bonjourService: BonjourService?
    
    private var frameCount: Int = 0
    private var fpsTimer: Timer?
    var permissionsManager = PermissionsManager()
    
    func startServer() {
        guard serverState == .idle else { return }
        
        permissionsManager.checkPermissions()
        if !permissionsManager.screenRecordingAllowed {
            print("❌ ERRORE: Permessi mancanti.")
            return
        }
        
        serverState = .starting
        currentPIN = String(format: "%04d", Int.random(in: 0...9999))
        
        udpStreamer = UDPStreamer()
        udpStreamer?.connect(to: tabletIP, port: 5554)
        
        videoEncoder = GPUVideoEncoder(width: width, height: height)
        videoEncoder?.fps = targetFPS
        videoEncoder?.delegate = self
        
        displaySource = DisplaySource()
        displaySource?.targetFPS = targetFPS
        displaySource?.delegate = self
        
        touchManager = TouchManager()
        touchManager?.delegate = self
        
        bonjourService = BonjourService(port: 5554)
        bonjourService?.publish(width: width, height: height, fps: targetFPS, pin: currentPIN)
        
        do {
            try videoEncoder?.start()
            try displaySource?.start(displayID: selectedDisplayID)
            try touchManager?.startListening()
            
            startStatisticsTimer()
            serverState = .streaming
            print("✅ SERVER AVVIATO.")
        } catch {
            print("❌ FALLIMENTO AVVIO: \(error)")
            stopServer()
        }
    }
    
    func stopServer() {
        serverState = .stopping
        fpsTimer?.invalidate()
        fpsTimer = nil
        
        displaySource?.stop()
        videoEncoder?.stop()
        touchManager?.stopListening()
        bonjourService?.unpublish()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.udpStreamer?.disconnect()
            self.serverState = .idle
            self.fps = 0
            self.tabletConnected = false
        }
    }
    
    private func startStatisticsTimer() {
        fpsTimer?.invalidate()
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let count = self.frameCount
            self.frameCount = 0
            DispatchQueue.main.async { self.fps = Double(count) }
        }
    }
}

extension ServerManager: DisplaySourceDelegate {
    func displaySource(_ source: DisplaySource, didCapturePixelBuffer pixelBuffer: CVPixelBuffer) {
        let now = CACurrentMediaTime()
        let pts = CMTime(seconds: now, preferredTimescale: 600)
        videoEncoder?.encodeFrame(pixelBuffer, presentationTime: pts)
        self.frameCount += 1
    }
    
    func displaySource(_ source: DisplaySource, didFailWithError error: Error) { stopServer() }
}

extension ServerManager: GPUVideoEncoderDelegate {
    func encoder(_ encoder: GPUVideoEncoder, didEncodeFrame data: Data, isKeyframe: Bool) {
        udpStreamer?.sendNAL(data)
    }
    func encoder(_ encoder: GPUVideoEncoder, didFailWithError error: Error) { stopServer() }
}

extension ServerManager: TouchManagerDelegate {
    func touchManager(_ manager: TouchManager, didReceiveTouch touch: TouchEvent) {
        if !tabletConnected { DispatchQueue.main.async { self.tabletConnected = true } }
    }
    func touchManager(_ manager: TouchManager, didChangeConnectionState connected: Bool) {
        DispatchQueue.main.async { self.tabletConnected = connected }
    }
}
