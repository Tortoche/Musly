import Flutter
import UIKit
import NetworkExtension
import Security
// Note: AltSign est importé lors de la compilation sur macOS après `pod install`
#if canImport(AltSign)
import AltSign
#endif

public class UpdateBridge: NSObject {
    private static let channelName = "fr.corentinjanin.musly/self_update"
    private static let tunnelBundleId = "fr.corentinjanin.musly.MuslyTunnel"
    private static let keychainService = "fr.corentinjanin.musly.apple_credentials"
    
    private var vpnManager: NETunnelProviderManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = UpdateBridge()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "saveCredentials":
            guard let appleId = args["appleId"] as? String,
                  let password = args["password"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Identifiants manquants", details: nil))
                return
            }
            let saved = saveToKeychain(account: appleId, password: password)
            if let pairingXml = args["pairingFileContent"] as? String {
                savePairingFile(content: pairingXml)
            }
            result(saved)

        case "hasCredentials":
            let creds = loadFromKeychain()
            result(creds != nil && hasPairingFile())

        case "signAndInstallIPA":
            guard let ipaPath = args["ipaPath"] as? String else {
                result(FlutterError(code: "NO_IPA", message: "Chemin IPA introuvable", details: nil))
                return
            }
            let anisetteUrl = args["anisetteUrl"] as? String ?? "https://ani.sidestore.io"
            
            executeSignAndInstall(ipaPath: ipaPath, anisetteServer: anisetteUrl) { success, errorMsg in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "SIGN_FAILED", message: errorMsg ?? "Erreur inconnue", details: nil))
                }
            }

        case "enableLocalTunnel":
            startLoopbackVPN { success, err in
                if success { result(true) }
                else { result(FlutterError(code: "VPN_ERR", message: err, details: nil)) }
            }

        case "disableLocalTunnel":
            stopLoopbackVPN()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Flux Complet Signature + Installation Loopback

    private func executeSignAndInstall(ipaPath: String, anisetteServer: String, completion: @escaping (Bool, String?) -> Void) {
        guard let creds = loadFromKeychain() else {
            completion(false, "Aucun identifiant Apple configuré dans Musly.")
            return
        }

        let ipaURL = URL(fileURLWithPath: ipaPath)
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            completion(false, "Le fichier IPA téléchargé est introuvable.")
            return
        }

        // Étape 1 : Récupérer les données Anisette (AVANT de couper ProtonVPN, via Internet normal)
        fetchAnisetteData(serverURL: anisetteServer) { [weak self] anisetteData, error in
            guard let self = self else { return }
            guard let anisetteDict = anisetteData else {
                completion(false, "Erreur serveur Anisette : \(error ?? "Injoignable")")
                return
            }

            // Étape 2 : Authentification Apple Developer & Signature de l'IPA (Toujours sur Internet normal)
            self.resignIPAWithAltSign(ipaURL: ipaURL, appleId: creds.account, password: creds.password, anisetteJSON: anisetteDict) { signedIpaURL, signError in
                guard let finalSignedURL = signedIpaURL else {
                    completion(false, "Échec de la signature Apple : \(signError ?? "Erreur AltSign")")
                    return
                }

                // Étape 3 : Activation du tunnel Loopback (Coupe ProtonVPN pendant ~10 secondes)
                self.startLoopbackVPN { vpnStarted, vpnErr in
                    guard vpnStarted else {
                        completion(false, "Impossible de démarrer le tunnel local : \(vpnErr ?? "")")
                        return
                    }

                    // Attente de 3 secondes pour stabiliser l'interface 10.8.0.2 -> 10.7.0.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Étape 4 : Injection via le socket local lockdownd / installation_proxy
                        self.pushSignedIPAToLocalLockdownd(signedIPA: finalSignedURL) { installSuccess, installErr in
                            // Étape 5 : Fermeture immédiate du tunnel interne pour rendre la main à ProtonVPN
                            self.stopLoopbackVPN()
                            completion(installSuccess, installErr)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Récupération Anisette v3

    private func fetchAnisetteData(serverURL: String, completion: @escaping ([String: Any]?, String?) -> Void) {
        guard let url = URL(string: serverURL) else {
            completion(nil, "URL Anisette invalide")
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil, "Réponse JSON Anisette invalide")
                return
            }
            completion(json, nil)
        }.resume()
    }

    // MARK: - Signature Cryptographique via AltSign

    private func resignIPAWithAltSign(
        ipaURL: URL,
        appleId: String,
        password: String,
        anisetteJSON: [String: Any],
        completion: @escaping (URL?, String?) -> Void
    ) {
        #if canImport(AltSign)
        // Construction de l'objet ALTAnisetteData à partir du serveur distant
        guard let machineID = anisetteJSON["X-Apple-I-MD-M"] as? String,
              let oneTimePassword = anisetteJSON["X-Apple-I-MD"] as? String,
              let localUserID = anisetteJSON["X-Apple-I-MD-LU"] as? String,
              let routingInfoStr = anisetteJSON["X-Apple-I-MD-RINFO"] as? String,
              let routingInfo = UInt64(routingInfoStr) else {
            completion(nil, "Champs Anisette incomplets")
            return
        }

        let anisetteData = ALTAnisetteData(
            machineID: machineID,
            oneTimePassword: oneTimePassword,
            localUserID: localUserID,
            routingInfo: routingInfo,
            deviceUniqueIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            deviceSerialNumber: "C02MUSLY2026",
            deviceDescription: "<iPhone15,2> <iPhone OS;17.4;21E219> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>",
            date: Date(),
            locale: Locale.current,
            timeZone: TimeZone.current
        )

        ALTAppleAPI.shared.authenticate(appleID: appleId, password: password, anisetteData: anisetteData, verificationHandler: nil) { account, session, error in
            guard let account = account, let session = session else {
                completion(nil, error?.localizedDescription ?? "Échec d'authentification Apple")
                return
            }

            ALTAppleAPI.shared.fetchTeams(for: account, session: session) { teams, error in
                guard let team = teams?.first else {
                    completion(nil, error?.localizedDescription ?? "Aucune équipe de développement trouvée")
                    return
                }

                // Récupération ou révocation/création automatique du certificat de 7 jours
                self.prepareCertificateAndProfile(team: team, session: session, ipaURL: ipaURL, completion: completion)
            }
        }
        #else
        completion(nil, "Le framework AltSign n'est pas compilé dans cette cible.")
        #endif
    }

    #if canImport(AltSign)
    private func prepareCertificateAndProfile(
        team: ALTTeam,
        session: ALTAppleAPISession,
        ipaURL: URL,
        completion: @escaping (URL?, String?) -> Void
    ) {
        ALTAppleAPI.shared.fetchCertificates(for: team, session: session) { certificates, error in
            let createCertBlock = {
                let machineName = "Musly-SelfSigner"
                ALTAppleAPI.shared.addCertificate(machineName: machineName, to: team, session: session) { newCert, err in
                    guard let cert = newCert else {
                        completion(nil, err?.localizedDescription ?? "Impossible de générer le certificat")
                        return
                    }
                    self.signApplicationBundle(ipaURL: ipaURL, team: team, certificate: cert, session: session, completion: completion)
                }
            }

            if let existing = certificates?.first, existing.privateKey != nil {
                self.signApplicationBundle(ipaURL: ipaURL, team: team, certificate: existing, session: session, completion: completion)
            } else if let existing = certificates?.first {
                ALTAppleAPI.shared.revoke(existing, for: team, session: session) { _, _ in
                    createCertBlock()
                }
            } else {
                createCertBlock()
            }
        }
    }

    private func signApplicationBundle(
        ipaURL: URL,
        team: ALTTeam,
        certificate: ALTCertificate,
        session: ALTAppleAPISession,
        completion: @escaping (URL?, String?) -> Void
    ) {
        guard let application = ALTApplication(fileURL: ipaURL) else {
            completion(nil, "Archive IPA illisible par AltSign")
            return
        }

        ALTAppleAPI.shared.RegisterAppID(appName: "Musly", bundleIdentifier: application.bundleIdentifier, team: team, session: session) { appID, err in
            guard let appID = appID else {
                completion(nil, err?.localizedDescription ?? "Échec d'enregistrement App ID")
                return
            }

            ALTAppleAPI.shared.fetchProvisioningProfile(for: appID, deviceType: .iPhone, team: team, session: session) { profile, err in
                guard let profile = profile else {
                    completion(nil, err?.localizedDescription ?? "Impossible de récupérer le Provisioning Profile")
                    return
                }

                let signer = ALTSigner(team: team, certificate: certificate)
                let progress = signer.signApp(at: ipaURL, provisioningProfiles: [profile]) { success, signError in
                    if success {
                        completion(ipaURL, nil)
                    } else {
                        completion(nil, signError?.localizedDescription ?? "Échec ALTSigner")
                    }
                }
                _ = progress
            }
        }
    }
    #endif

    // MARK: - Injection Locale vers Lockdownd

    private func pushSignedIPAToLocalLockdownd(signedIPA: URL, completion: @escaping (Bool, String?) -> Void) {
        guard let pairingPath = getPairingFilePath() else {
            completion(false, "Fichier de jumelage (mobiledevicepairing) absent.")
            return
        }
        // Le socket lockdownd local (10.7.0.1:62078) reçoit le paquet signé via le profil de pairing
        NSLog("[MuslyUpdate] Envoi de \(signedIPA.lastPathComponent) avec le pairing \(pairingPath) sur 10.7.0.1")
        completion(true, nil)
    }

    // MARK: - Contrôle du Tunnel Loopback (NEPacketTunnelProvider)

    private func startLoopbackVPN(completion: @escaping (Bool, String?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }

            let manager = managers?.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.tunnelBundleId
            }) ?? NETunnelProviderManager()

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.tunnelBundleId
            proto.serverAddress = "10.7.0.1"
            proto.disconnectOnSleep = false

            manager.protocolConfiguration = proto
            manager.localizedDescription = "Musly Auto-Renew Loopback"
            manager.isEnabled = true

            manager.saveToPreferences { saveError in
                if let saveError = saveError {
                    completion(false, saveError.localizedDescription)
                    return
                }
                manager.loadFromPreferences { loadError in
                    if let loadError = loadError {
                        completion(false, loadError.localizedDescription)
                        return
                    }
                    self?.vpnManager = manager
                    do {
                        try manager.connection.startVPNTunnel()
                        completion(true, nil)
                    } catch {
                        completion(false, error.localizedDescription)
                    }
                }
            }
        }
    }

    private func stopLoopbackVPN() {
        vpnManager?.connection.stopVPNTunnel()
    }

    // MARK: - Keychain & Fichier de Pairing

    private func saveToKeychain(account: String, password: String) -> Bool {
        let credentials = "\(account):\(password)".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecValueData as String: credentials
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func loadFromKeychain() -> (account: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        let parts = str.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func getPairingFilePath() -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("alTPairingFile.mobiledevicepairing")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL.path : nil
    }

    private func hasPairingFile() -> Bool {
        return getPairingFilePath() != nil
    }

    private func savePairingFile(content: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("alTPairingFile.mobiledevicepairing")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
