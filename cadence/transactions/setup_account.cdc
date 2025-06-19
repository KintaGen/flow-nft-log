import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

// This transaction is what an account would run to set itself up to receive NFTs.
// It explicitly requests the necessary permissions (capabilities) to modify account storage.

transaction {

    // FIXED: Added the required capabilities (SaveValue, IssueStorageCapabilityController, etc.)
    // to the auth() list to grant the transaction permission to modify storage.
    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view from the ExampleNFT contract")

        let storagePath = collectionData.storagePath
        let publicPath = collectionData.publicPath

        // Return early if the account already has a collection
        if signer.storage.borrow<&ExampleNFT.Collection>(from: storagePath) != nil {
            log("Account already has an ExampleNFT Collection.")
            return
        }

        // Create a new empty collection
        log("Creating a new ExampleNFT Collection...")
        let collection <- ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())

        // Save it to the account's storage. This requires the `SaveValue` capability.
        signer.storage.save(<-collection, to: storagePath)
        log("Collection saved to storage path: ".concat(storagePath.toString()))

        // Unpublish any existing capability at the public path to avoid errors.
        // This requires the `UnpublishCapability` capability.
        signer.capabilities.unpublish(publicPath)

        // Issue a new storage capability. This requires the `IssueStorageCapabilityController` capability.
        let collectionCap = signer.capabilities.storage.issue<&ExampleNFT.Collection>(storagePath)
        
        // Publish the capability to the public path. This requires the `PublishCapability` capability.
        signer.capabilities.publish(collectionCap, at: publicPath)
        log("Public capability published at path: ".concat(publicPath.toString()))
    }

    execute {
        log("Account setup successful!")
    }
}