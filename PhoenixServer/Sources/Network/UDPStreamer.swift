import Foundation
import Network

class UDPStreamer {
    private var connection: NWConnection?
    private let sendQueue = DispatchQueue(label: "phoenix.udp.send", qos: .userInteractive)
    private var isReady = false
    
    func connect(to host: String, port: UInt16 = 5554) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let params = NWParameters.udp
        // Disabilitiamo il buffering per ridurre la latenza
        params.allowFastOpen = true
        
        connection = NWConnection(to: endpoint, using: params)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isReady = true
                print("📡 UDP: Connessione pronta verso \(host)")
            case .failed(let error):
                print("❌ UDP: Errore connessione: \(error)")
                self?.isReady = false
            case .cancelled:
                self?.isReady = false
            default: break
            }
        }
        
        connection?.start(queue: sendQueue)
    }
    
    func sendNAL(_ nalData: Data) {
        guard isReady else { return } // Evita l'errore 89 se la connessione è chiusa
        
        connection?.send(content: nalData, completion: .contentProcessed { error in
            // Non stampiamo nulla qui per non intasare la console,
            // l'errore 89 verrà ignorato dal check 'isReady'
        })
    }
    
    func disconnect() {
        isReady = false
        connection?.cancel()
        connection = nil
    }
}
