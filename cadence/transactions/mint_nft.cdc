import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

// Mints a new ExampleNFT and deposits it into a recipient's Collection.
// This is the "CREATE" operation for your NFT database.
// Must be signed by the account holding the Minter resource.

transaction(
    recipient: Address,
    inputs: [UInt64],
    agent: String,
    outputCID: String,
    runHash: String
) {
    let minter: &ExampleNFT.Minter
    let recipientCollectionRef: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view")

        self.minter = signer.storage.borrow<&ExampleNFT.Minter>(from: ExampleNFT.MinterStoragePath)
            ?? panic("Signer does not store a Minter at ".concat(ExampleNFT.MinterStoragePath.toString()))

        self.recipientCollectionRef = getAccount(recipient).capabilities
            .borrow<&{NonFungibleToken.Receiver}>(collectionData.publicPath)
            ?? panic("Could not borrow receiver capability from recipient")
    }

    execute {
        let newNFT <- self.minter.mint(
            inputs: inputs,
            agent: agent,
            outputCID: outputCID,
            runHash: runHash
        )
        let id = newNFT.id
        self.recipientCollectionRef.deposit(token: <-newNFT)
        log("Successfully minted NFT with id ".concat(id.toString()))
    }
}