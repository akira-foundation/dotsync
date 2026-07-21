import AppKit
import DotSyncCore

extension SyncViewModel {
    var machineHost: String {
        ProcessInfo.processInfo.hostName.split(separator: ".").first.map(String.init) ?? "pc"
    }

    func enableEncryption() {
        guard AgeCrypto.available else {
            presentAgeMissing()
            return
        }
        let recipient: String
        if let existing = settings.encryption.recipient, Keychain.identity() != nil {
            recipient = existing
        } else {
            guard let keypair = try? AgeCrypto().generateKeypair() else { return }
            Keychain.setIdentity(keypair.identity)
            recipient = keypair.recipient
        }
        settings.encryption.enabled = true
        settings.encryption.host = machineHost
        settings.encryption.recipient = recipient
        saveSettings()
        registerRecipientInAllRoots(recipient)
        refresh()
    }

    func disableEncryption() {
        settings.encryption.enabled = false
        saveSettings()
    }

    private func registerRecipientInAllRoots(_ recipient: String) {
        guard let config = try? Config.load(configURL) else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        for root in config.roots {
            let existing = Recipients.load(root.expandedPath).first { $0.host == machineHost }
            try? Recipients.upsert(
                Recipient(
                    host: machineHost, publicKey: recipient,
                    created: existing?.created ?? now, lastSeen: now),
                in: root.expandedPath)
        }
    }

    private func presentAgeMissing() {
        let alert = NSAlert()
        alert.messageText = "age is required"
        alert.informativeText = "Install it with `brew install age`, then enable encryption."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    nonisolated static func encryptBeforeSync(
        repo: URL, encryption: EncryptionSettings, host: String
    ) {
        guard encryption.enabled, AgeCrypto.available, let recipient = encryption.recipient else {
            return
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let existing = Recipients.load(repo).first { $0.host == host }
        try? Recipients.upsert(
            Recipient(
                host: host, publicKey: recipient, created: existing?.created ?? now, lastSeen: now),
            in: repo)
        try? EncryptionCoordinator.encryptAll(
            repo: repo, age: AgeCrypto(), recipients: Recipients.publicKeys(repo))
    }

    nonisolated static func decryptAfterSync(repo: URL, encryption: EncryptionSettings) {
        guard encryption.enabled, AgeCrypto.available, let identity = Keychain.identity() else {
            return
        }
        try? EncryptionCoordinator.decryptAll(repo: repo, age: AgeCrypto(), identity: identity)
    }
}
