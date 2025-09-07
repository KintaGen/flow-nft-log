import "KintaGenNFTPaid"
import "FlowToken"

transaction() {
    prepare(signer: auth(BorrowValue, SaveValue, StorageCapabilities, PublishCapability) &Account) {
        if signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            signer.storage.save(<- FlowToken.createEmptyVault(), to: /storage/flowTokenVault)
        }
        if signer.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver).borrow() == nil {
            let cap = signer.capabilities.storage.issue<&FlowToken.Vault>(/storage/flowTokenVault)
            signer.capabilities.publish(cap, at: /public/flowTokenReceiver)
        }

        if signer.storage.borrow<&KintaGenNFTPaid.Collection>(from: /storage/kintagenPaidCollection) == nil {
            signer.storage.save(
                <- KintaGenNFTPaid.createEmptyCollection(nftType: Type<@KintaGenNFTPaid.NFT>()),
                to: /storage/kintagenPaidCollection
            )
            let colCap = signer.capabilities.storage.issue<&KintaGenNFTPaid.Collection>(/storage/kintagenPaidCollection)
            signer.capabilities.publish(colCap, at: /public/kintagenPaidCollection)
        }
    }
}
