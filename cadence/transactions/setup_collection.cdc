// IMPORTANT: Make sure the contract name and address in your flow.json are correct
import NonFungibleToken from 0x631e88ae7f1d7c20
import KintaGenNFT from 0x3c16354a3859c81b

// This transaction fixes a user's account by creating a public link
// to their KintaGenNFT Collection if it doesn't already exist.
transaction {
    prepare(signer: auth(Capabilities) &Account) {
        // First, check if a collection even exists in private storage.
        // If not, create one. This is a safety measure.
        if signer.storage.borrow<&KintaGenNFT.Collection>(from: KintaGenNFT.CollectionStoragePath) == nil {
            let collection <- KintaGenNFT.createEmptyCollection(nftType: Type<@KintaGenNFT.NFT>())
            signer.storage.save(<-collection, to: KintaGenNFT.CollectionStoragePath)
            log("No collection found. A new one was created in storage.")
        }

        // Check if the public link is already set up and valid. If so, do nothing.
        if signer.capabilities.get<&{NonFungibleToken.CollectionPublic}>(KintaGenNFT.CollectionPublicPath).check() {
            log("Public link already exists and is valid. No action needed.")
            return
        }

        // If the link is missing or broken, create a new one.
        // First, safely unpublish any potentially broken link at the path.
        signer.capabilities.unpublish(KintaGenNFT.CollectionPublicPath)

        // Then, publish a new, correct link from private storage.
        signer.capabilities.publish(
            signer.capabilities.storage.issue<&{NonFungibleToken.CollectionPublic}>(KintaGenNFT.CollectionStoragePath),
            at: KintaGenNFT.CollectionPublicPath
        )
        log("Successfully published a new public link to the collection.")
    }
}