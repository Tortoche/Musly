import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // Attribution d'une IP locale sur le sous-réseau virtuel
        let ipv4Settings = NEIPv4Settings(addresses: ["10.8.0.2"], subnetMasks: ["255.255.255.0"])
        
        // Route stricte uniquement vers le loopback pour intercepter usbmuxd/lockdownd
        let loopbackRoute = NEIPv4Route(destinationAddress: "127.0.0.1", subnetMask: "255.255.255.255")
        ipv4Settings.includedRoutes = [loopbackRoute]
        
        settings.ipv4Settings = ipv4Settings
        settings.mtu = 1400

        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                NSLog("[MuslyTunnel] Échec du montage loopback : \(error.localizedDescription)")
                completionHandler(error)
            } else {
                NSLog("[MuslyTunnel] Tunnel loopback 127.0.0.1 actif.")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[MuslyTunnel] Arrêt du tunnel loopback.")
        completionHandler()
    }
}
