import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

transaction(recipient: Address, agent: String, outputCID: String, runHash: String) {
    let minter: &ExampleNFT.Minter
    let recipientCollectionRef: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        self.minter = signer.storage.borrow<&ExampleNFT.Minter>(from: ExampleNFT.MinterStoragePath)
            ?? panic("Signer does not store a Minter.")
            
        self.recipientCollectionRef = getAccount(recipient).capabilities.borrow<&{NonFungibleToken.Receiver}>(collectionData.publicPath)
            ?? panic("Could not borrow receiver capability from recipient.")
    }

    execute {
        let newNFT <- self.minter.mint(agent: agent, outputCID: outputCID, runHash: runHash)
        let id = newNFT.id
        self.recipientCollectionRef.deposit(token: <-newNFT)
        log("Successfully minted NFT with ID: ".concat(id.toString()))
    }
}