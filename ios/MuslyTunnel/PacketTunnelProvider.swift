import NetworkExtension
import Foundation

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var isRunning = false

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.7.0.1")
        
        // Attribution d'une IP locale sur le sous-réseau virtuel (LocalDevVPN reflector)
        let ipv4Settings = NEIPv4Settings(addresses: ["10.7.0.2"], subnetMasks: ["255.255.255.0"])
        
        // Route stricte uniquement vers le peer 10.7.0.1/32 pour intercepter le loopback lockdown
        let loopbackRoute = NEIPv4Route(destinationAddress: "10.7.0.1", subnetMask: "255.255.255.255")
        ipv4Settings.includedRoutes = [loopbackRoute]
        ipv4Settings.excludedRoutes = []
        
        settings.ipv4Settings = ipv4Settings
        settings.mtu = 1400

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error = error {
                NSLog("[MuslyTunnel] Échec du montage loopback : \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            NSLog("[MuslyTunnel] Tunnel loopback actif sur 10.7.0.1 (reflector).")
            self?.isRunning = true
            self?.readPacketLoop()
            completionHandler(nil)
        }
    }

    private func readPacketLoop() {
        guard isRunning else { return }
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.isRunning else { return }
            
            var reflectedPackets: [Data] = []
            var reflectedProtocols: [NSNumber] = []
            
            for (index, packet) in packets.enumerated() {
                if let reflected = self.reflectIPv4Packet(packet) {
                    reflectedPackets.append(reflected)
                    reflectedProtocols.append(protocols[index])
                }
            }
            
            if !reflectedPackets.isEmpty {
                self.packetFlow.writePackets(reflectedPackets, withProtocols: reflectedProtocols)
            }
            
            self.readPacketLoop()
        }
    }

    /// Inverse la source et la destination d'un paquet IPv4 (technique LocalDevVPN reflector)
    private func reflectIPv4Packet(_ packet: Data) -> Data? {
        guard packet.count >= 20 else { return nil }
        
        var buffer = [UInt8](packet)
        let versionAndIHL = buffer[0]
        guard (versionAndIHL >> 4) == 4 else { return nil } // Uniquement IPv4
        let ihl = Int(versionAndIHL & 0x0F) * 4
        guard packet.count >= ihl else { return nil }
        
        let protocolType = buffer[9]
        
        // Inversion IP source (octets 12..15) et IP destination (octets 16..19)
        for i in 0..<4 {
            let tmp = buffer[12 + i]
            buffer[12 + i] = buffer[16 + i]
            buffer[16 + i] = tmp
        }
        
        // Recalcul du Checksum IP (octets 10..11)
        buffer[10] = 0
        buffer[11] = 0
        let ipChecksum = computeChecksum(buffer, start: 0, length: ihl)
        buffer[10] = UInt8(ipChecksum >> 8)
        buffer[11] = UInt8(ipChecksum & 0xFF)
        
        // Inversion des ports TCP/UDP si présents
        if (protocolType == 6 || protocolType == 17) && buffer.count >= ihl + 4 {
            let srcPort0 = buffer[ihl]
            let srcPort1 = buffer[ihl + 1]
            buffer[ihl] = buffer[ihl + 2]
            buffer[ihl + 1] = buffer[ihl + 3]
            buffer[ihl + 2] = srcPort0
            buffer[ihl + 3] = srcPort1
            
            // Checksum TCP/UDP optionnel
            if protocolType == 6 && buffer.count >= ihl + 18 {
                buffer[ihl + 16] = 0
                buffer[ihl + 17] = 0
            } else if protocolType == 17 && buffer.count >= ihl + 8 {
                buffer[ihl + 6] = 0
                buffer[ihl + 7] = 0
            }
        }
        
        return Data(buffer)
    }

    private func computeChecksum(_ buffer: [UInt8], start: Int, length: Int) -> UInt16 {
        var sum: UInt32 = 0
        var i = start
        while i < start + length - 1 {
            let word = (UInt32(buffer[i]) << 8) + UInt32(buffer[i + 1])
            sum += word
            i += 2
        }
        if i < start + length {
            sum += UInt32(buffer[i]) << 8
        }
        while (sum >> 16) != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[MuslyTunnel] Arrêt du tunnel loopback.")
        isRunning = false
        completionHandler()
    }
}
