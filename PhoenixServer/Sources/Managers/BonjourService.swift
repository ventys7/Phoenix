//
//  BonjourService.swift
//  PhoenixServer
//
//  NetService (Bonjour) publisher for device discovery
//

import Foundation

class BonjourService: NSObject, ObservableObject {
    private var service: NetService?
    private var isPublished = false
    
    @Published var serviceName: String = ""
    @Published var isAvailable: Bool = false
    
    let SERVICE_TYPE = "_phoenix._udp"
    let SERVICE_DOMAIN = "local."
    
    private let port: Int
    
    init(port: Int = 5554) {
        self.port = port
        super.init()
    }
    
    func publish(width: Int, height: Int, fps: Int, pin: String) {
        guard !isPublished else { return }
        
        let hostName = Host.current().localizedName ?? "Mac"
        serviceName = "\(hostName)"
        
        service = NetService(
            domain: SERVICE_DOMAIN,
            type: SERVICE_TYPE,
            name: serviceName,
            port: Int32(port)
        )
        
        let txtRecord: [String: Data] = [
            "width": "\(width)".data(using: .utf8)!,
            "height": "\(height)".data(using: .utf8)!,
            "fps": "\(fps)".data(using: .utf8)!,
            "pin": pin.data(using: .utf8)!,
            "version": "1.0".data(using: .utf8)!
        ]
        
        service?.setTXTRecord(NetService.data(fromTXTRecord: txtRecord))
        service?.delegate = self
        
        service?.publish(options: [.listenForConnections])
        
        isPublished = true
        isAvailable = true
        
        print("Bonjour: Published service '\(serviceName)' on port \(port)")
    }
    
    func unpublish() {
        guard isPublished else { return }
        
        service?.stop()
        service = nil
        isPublished = false
        isAvailable = false
        
        print("Bonjour: Service unpublished")
    }
}

extension BonjourService: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isAvailable = true
            print("Bonjour: Service is now available")
        }
    }
    
    func netServiceDidStop(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isAvailable = false
            print("Bonjour: Service stopped")
        }
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Bonjour: Failed to publish - \(errorDict)")
    }
}
