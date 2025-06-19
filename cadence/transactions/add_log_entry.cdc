import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

transaction(nftID: UInt64, agent: String, actionDescription: String, outputCID: String) {
    let nftRef: &ExampleNFT.NFT

    prepare(signer: auth(BorrowValue) &Account) {
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        let collection = signer.storage.borrow<&ExampleNFT.Collection>(from: collectionData.storagePath)
            ?? panic("Could not borrow a reference to the owner's Collection")
            
        self.nftRef = collection.borrowNFT(nftID)! as! &ExampleNFT.NFT
    }

    execute {
        self.nftRef.addLogEntry(
            agent: agent,
            actionDescription: actionDescription,
            outputCID: outputCID
        )
        log("Successfully added new log entry to NFT with ID: ".concat(nftID.toString()))
    }
}