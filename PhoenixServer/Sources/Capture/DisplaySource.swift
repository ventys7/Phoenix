import Foundation
import CoreGraphics
import IOSurface
import AppKit

protocol DisplaySourceDelegate: AnyObject {
    func displaySource(_ source: DisplaySource, didCapturePixelBuffer pixelBuffer: CVPixelBuffer)
    func displaySource(_ source: DisplaySource, didFailWithError error: Error)
}

enum DisplaySourceError: Error { case streamCreationFailed }

class DisplaySource: NSObject {
    weak var delegate: DisplaySourceDelegate?
    let targetWidth = 1024
    let targetHeight = 768
    var targetFPS: Int = 30
    
    private var displayStream: CGDisplayStream?
    private var isRunning = false
    private let captureQueue = DispatchQueue(label: "phoenix.capture", qos: .userInteractive)
    private var lastFrameTime = CACurrentMediaTime()

    func getAvailableDisplays() -> [(id: CGDirectDisplayID, name: String)] {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &displays, &displayCount) == .success else {
            return [(CGMainDisplayID(), "Monitor Principale")]
        }
        
        return Array(displays[0..<Int(displayCount)]).map { id in
            if let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id }) {
                return (id: id, name: screen.localizedName)
            }
            let isVirtual = CGDisplayIsBuiltin(id) == 0 && CGDisplayIsMain(id) == 0
            return (id: id, name: isVirtual ? "Monitor Virtuale (\(id))" : "Monitor Esterno (\(id))")
        }
    }

    func start(displayID: CGDirectDisplayID) throws {
        guard !isRunning else { return }
        
        let properties: [String: Any] = [
            (CGDisplayStream.preserveAspectRatio as String): true,
            (CGDisplayStream.showCursor as String): true,
            (CGDisplayStream.minimumFrameTime as String): 1.0 / Double(targetFPS)
        ]
        
        displayStream = CGDisplayStream(
            dispatchQueueDisplay: displayID,
            outputWidth: targetWidth,
            outputHeight: targetHeight,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: properties as CFDictionary,
            queue: captureQueue,
            handler: { [weak self] (status, _, ioSurface, _) in
                guard let self = self, status == .frameComplete, let surface = ioSurface else { return }
                let currentTime = CACurrentMediaTime()
                if currentTime - self.lastFrameTime < (1.0 / Double(self.targetFPS)) - 0.005 { return }
                self.lastFrameTime = currentTime
                
                var buffer: Unmanaged<CVPixelBuffer>?
                if CVPixelBufferCreateWithIOSurface(nil, surface, nil, &buffer) == kCVReturnSuccess {
                    self.delegate?.displaySource(self, didCapturePixelBuffer: buffer!.takeRetainedValue())
                }
            }
        )
        
        if displayStream?.start() != .success { throw DisplaySourceError.streamCreationFailed }
        isRunning = true
    }
    
    func stop() { isRunning = false; displayStream?.stop(); displayStream = nil }
}
