import "FlowToken"

transaction() {
    prepare(signer: auth(BorrowValue, SaveValue, StorageCapabilities, PublishCapability) &Account) {
        // Create a Flow vault if missing (common on testnet)
        if signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            signer.storage.save(<- FlowToken.createEmptyVault(), to: /storage/flowTokenVault)
        }
        // Publish / re-publish the public receiver
        if signer.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver).borrow() == nil {
            let cap = signer.capabilities.storage.issue<&FlowToken.Vault>(/storage/flowTokenVault)
            signer.capabilities.publish(cap, at: /public/flowTokenReceiver)
        }
    }
}
