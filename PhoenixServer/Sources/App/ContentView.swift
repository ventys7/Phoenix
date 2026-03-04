import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var availableDisplays: [(id: CGDirectDisplayID, name: String)] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                displaySelectorSection
                Divider()

                if serverManager.serverState == .streaming {
                    streamingStatsSection
                } else {
                    idleSettingsSection
                }

                Spacer(minLength: 20)
                actionButtonSection
            }
            .padding(25)
        }
        .frame(minWidth: 400, maxWidth: 550, minHeight: 400, maxHeight: 800)
        .onAppear {
            updateDisplayList()
            serverManager.permissionsManager.checkPermissions()
        }
    }

    // --- SEZIONI PRIVATE ---
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Phoenix Server")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                StatusBadge(state: serverManager.serverState)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 45, height: 45)
                .foregroundColor(.orange)
        }
    }

    private var displaySelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Select Display", systemImage: "desktopcomputer").font(.headline)
            Picker("", selection: $serverManager.selectedDisplayID) {
                if availableDisplays.isEmpty {
                    Text("Ricerca monitor...").tag(CGMainDisplayID())
                } else {
                    ForEach(availableDisplays, id: \.id) { display in
                        Text(display.name).tag(display.id)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(serverManager.serverState != .idle)
        }
        .padding(12).background(Color.secondary.opacity(0.1)).cornerRadius(10)
    }

    private var streamingStatsSection: some View {
        VStack(spacing: 15) {
            PINView(pin: serverManager.currentPIN)
            // Bitrate rimosso dai parametri perché ora è fisso a 2.5 Mbps
            DashboardView(fps: serverManager.fps, tabletConnected: serverManager.tabletConnected)
        }
    }

    private var idleSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PermissionsView()
            
            Text("Stream Quality")
                .font(.headline)
            
            Text("Configurazione automatica ottimizzata per la stabilità (2.5 Mbps).")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding().background(Color.secondary.opacity(0.05)).cornerRadius(10)
    }

    private var actionButtonSection: some View {
        Button(action: { serverManager.serverState == .idle ? serverManager.startServer() : serverManager.stopServer() }) {
            HStack {
                if serverManager.serverState == .starting || serverManager.serverState == .stopping {
                    ProgressView().controlSize(.small).padding(.trailing, 5)
                }
                Text(serverManager.serverState == .streaming ? "STOP STREAMING" : "START PHOENIX").fontWeight(.black)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(serverManager.serverState == .streaming ? .red : .blue)
    }

    private func updateDisplayList() {
        let source = DisplaySource()
        self.availableDisplays = source.getAvailableDisplays()
    }
}

// MARK: - SUBVIEWS

struct StatusBadge: View {
    let state: ServerState
    var statusColor: Color {
        switch state {
        case .idle: return .gray
        case .starting, .stopping: return .orange
        case .streaming: return .green
        }
    }
    var body: some View {
        HStack {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(state.rawValue.uppercased()).font(.caption).fontWeight(.bold)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(statusColor.opacity(0.15)).cornerRadius(8)
    }
}

struct PermissionsView: View {
    @EnvironmentObject var serverManager: ServerManager
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("System Permissions").font(.headline)
            HStack {
                PermissionLabel(name: "Screen", isGranted: serverManager.permissionsManager.screenRecordingAllowed)
                Spacer()
                PermissionLabel(name: "Accessibility", isGranted: serverManager.permissionsManager.accessibilityAllowed)
            }
            if !serverManager.permissionsManager.allPermissionsGranted {
                Button("Fix Permissions") {
                    serverManager.permissionsManager.triggerSystemPermissionPopup()
                }.buttonStyle(.link).font(.caption)
            }
        }
    }
}

struct PermissionLabel: View {
    let name: String; let isGranted: Bool
    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").foregroundColor(isGranted ? .green : .red)
            Text(name).font(.caption)
        }
    }
}

struct PINView: View {
    let pin: String
    var body: some View {
        VStack(spacing: 5) {
            Text("TABLET PAIRING PIN").font(.caption2).foregroundColor(.secondary)
            Text(pin).font(.system(size: 40, weight: .black, design: .monospaced)).foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity).padding().background(Color.blue.opacity(0.05)).cornerRadius(12)
    }
}

struct DashboardView: View {
    let fps: Double; let tabletConnected: Bool
    var body: some View {
        HStack {
            VStack {
                Text("\(Int(fps))").fontWeight(.bold)
                Text("FPS").font(.caption2)
            }.frame(maxWidth: .infinity)
            
            VStack {
                Text("2.5").fontWeight(.bold)
                Text("MBPS").font(.caption2)
            }.frame(maxWidth: .infinity)
            
            VStack {
                Text(tabletConnected ? "LIVE" : "WAIT").fontWeight(.bold).foregroundColor(tabletConnected ? .green : .orange)
                Text("CLIENT").font(.caption2)
            }.frame(maxWidth: .infinity)
        }
        .padding().background(Color.secondary.opacity(0.1)).cornerRadius(12)
    }
}
