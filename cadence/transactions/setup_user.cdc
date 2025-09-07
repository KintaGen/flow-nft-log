import KintaGenNFT from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79

transaction() {
    prepare(signer: auth(BorrowValue, SaveValue, StorageCapabilities, PublishCapability) &Account) {
        // Ensure FlowToken receiver is published (vault must already exist on emulator service account)
        let flowVault = signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("FlowToken Vault missing in /storage/flowTokenVault")
        let flowRx = signer.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver).borrow()
        if flowRx == nil {
            let cap = signer.capabilities.storage.issue<&FlowToken.Vault>(/storage/flowTokenVault)
            signer.capabilities.publish(cap, at: /public/flowTokenReceiver)
        }

        // Ensure KintaGenNFT collection + public capability
        if signer.storage.borrow<&KintaGenNFT.Collection>(from: /storage/kintagenNFTCollection) == nil {
            signer.storage.save(
                <- KintaGenNFT.createEmptyCollection(nftType: Type<@KintaGenNFT.NFT>()),
                to: /storage/kintagenNFTCollection
            )
            let colCap = signer.capabilities.storage.issue<&KintaGenNFT.Collection>(/storage/kintagenNFTCollection)
            signer.capabilities.publish(colCap, at: /public/kintagenNFTCollection)
        }
    }
}
