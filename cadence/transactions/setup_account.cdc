import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

// Prepares an account to receive NFTs by creating a Collection resource
// and publishing a public capability to it.
transaction {
    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        
        // Dynamically get the collection path info from the contract
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        // Return early if a collection already exists
        if signer.storage.borrow<&ExampleNFT.Collection>(from: collectionData.storagePath) != nil {
            log("Account already has a collection.")
            return
        }
        
        log("Creating a new collection...")
        let collection <- ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
        
        // Save the new collection to the account's storage
        signer.storage.save(<-collection, to: collectionData.storagePath)
        
        // Unpublish any old capability at the path to be safe
        signer.capabilities.unpublish(collectionData.publicPath)
        
        // Issue a new capability for the collection
        let collectionCap = signer.capabilities.storage.issue<&ExampleNFT.Collection>(collectionData.storagePath)
        
        // --- THIS IS THE FIX ---
        // The variable is named `collectionCap`, not `cap`.
        signer.capabilities.publish(collectionCap, at: collectionData.publicPath)
        
        log("Collection setup complete.")
    }
}