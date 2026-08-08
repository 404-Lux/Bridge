import SwiftUI
import PhotosUI

struct MainView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var transferManager = TransferManager.shared
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPhotoClipboardMode = false
    @State private var showingDiagnostics = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Human-Readable Connection Card
                    VStack(spacing: 8) {
                        HStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 12, height: 12)
                            Text(humanReadableStatus)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            if networkManager.state == .reconnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }

                        if !networkManager.connectedDeviceName.isEmpty {
                            HStack {
                                Text("Paired with:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(networkManager.connectedDeviceName)
                                    .font(.caption)
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)

                    // Quick Actions Section
                    if networkManager.state == .connected {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Actions")
                                .font(.headline)

                            // 1. Send Clipboard
                            Button(action: {
                                if let currentClipboard = UIPasteboard.general.string, !currentClipboard.isEmpty {
                                    networkManager.sendClipboardPayload(text: currentClipboard)
                                }
                            }) {
                                Label("Send Clipboard", systemImage: "doc.on.clipboard")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }

                            // 2. Send Photo to PC Downloads
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Send Photo to PC", systemImage: "photo")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.secondary.opacity(0.15))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                if let item = newItem {
                                    handlePhotoSelected(item: item, toClipboard: false)
                                }
                            }

                            // 3. Signature Feature: Photo to Windows Clipboard (Ctrl+V)
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Copy Photo to PC Clipboard (Ctrl+V)", systemImage: "photo.badge.plus")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                if let item = newItem {
                                    handlePhotoSelected(item: item, toClipboard: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                    } else {
                        VStack(spacing: 12) {
                            Button(action: {
                                networkManager.startDiscovery()
                            }) {
                                Label("Look for Windows PC", systemImage: "wifi.radiowaves.left.and.right")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                    }

                    // Active Transfers List
                    if !transferManager.activeTransfers.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Transfers")
                                .font(.headline)

                            ForEach(transferManager.activeTransfers) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.filename)
                                            .font(.subheadline)
                                            .bold()
                                        Spacer()
                                        Text(item.state.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    ProgressView(value: item.progressPct)
                                }
                                .padding(10)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                    }

                    // Recent Activity Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Activity")
                            .font(.headline)

                        if !networkManager.lastSentClipboard.isEmpty {
                            HStack {
                                Image(systemName: "arrow.up.doc")
                                    .foregroundColor(.blue)
                                Text("Sent text: \"\(networkManager.lastSentClipboard.prefix(30))...\"")
                                    .font(.caption)
                                Spacer()
                            }
                        }

                        if !networkManager.lastReceivedClipboard.isEmpty {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                    .foregroundColor(.green)
                                Text("Received: \"\(networkManager.lastReceivedClipboard.prefix(30))...\"")
                                    .font(.caption)
                                Spacer()
                            }
                        }

                        if networkManager.lastSentClipboard.isEmpty && networkManager.lastReceivedClipboard.isEmpty {
                            Text("No recent transfers yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)

                    // Diagnostic Logs Toggle
                    DisclosureGroup("Developer Diagnostics", isExpanded: $showingDiagnostics) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(networkManager.diagnosticLogs) { log in
                                HStack {
                                    Text(log.timestamp)
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.blue)
                                    Text(log.stateTransition)
                                        .font(.caption2)
                                    Spacer()
                                    Text(log.reason)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.caption)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .padding()
            }
            .navigationTitle("Bridge")
            .onAppear {
                networkManager.startDiscovery()
            }
        }
    }

    private func handlePhotoSelected(item: PhotosPickerItem, toClipboard: Bool) {
        PhotoManager.shared.loadJPEGData(from: item) { data, filename in
            if let data = data, let filename = filename {
                let header = TransferManager.shared.createTransferHeader(
                    filename: filename,
                    fileSize: UInt64(data.count),
                    isPhotoClipboard: toClipboard
                )
                if let jsonData = try? JSONSerialization.data(withJSONObject: header) {
                    networkManager.sendClipboardPayload(text: String(data: jsonData, encoding: .utf8) ?? "")
                }
            }
        }
    }

    private var humanReadableStatus: String {
        switch networkManager.state {
        case .connected: return "iPhone Connected"
        case .discovering: return "Looking for your PC..."
        case .connecting: return "Connecting to PC..."
        case .authenticating: return "Securing Session..."
        case .reconnecting: return "Reconnecting..."
        case .networkUnavailable: return "Wi-Fi Unavailable"
        case .pairingRequired: return "Pair Your iPhone"
        case .error: return "PC Unavailable"
        case .disconnected: return "Disconnected"
        }
    }

    private var statusColor: Color {
        switch networkManager.state {
        case .connected: return .green
        case .connecting, .authenticating, .discovering: return .orange
        case .reconnecting: return .yellow
        case .networkUnavailable, .pairingRequired, .error: return .red
        case .disconnected: return .gray
        }
    }
}
