import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT"

access(all) struct NFTData {
    access(all) let id: UInt64
    access(all) let name: String
    access(all) let description: String
    access(all) let thumbnailCID: String
    access(all) let traits: {String: AnyStruct}

    init(id: UInt64, display: MetadataViews.Display, traits: MetadataViews.Traits) {
        self.id = id
        self.name = display.name
        self.description = display.description
        
        let ipfsFile = display.thumbnail as! MetadataViews.IPFSFile
        self.thumbnailCID = ipfsFile.cid

        var traitsDict: {String: AnyStruct} = {}
        for trait in traits.traits {
            traitsDict[trait.name] = trait.value
        }
        self.traits = traitsDict
    }
}

access(all) fun main(ownerAddress: Address, nftID: UInt64): NFTData? {

    let owner = getAccount(ownerAddress)

    // Step 1: Get the capability. This returns an optional: Capability?
    let collectionCap = owner.capabilities.get<&ExampleNFT.Collection>(ExampleNFT.CollectionPublicPath)

    // --- THIS IS THE FIX ---
    // Step 2: Explicitly check if the optional is nil and panic if it is.
    // This replaces the `?? panic(...)` one-liner and is clearer for the compiler.
    if collectionCap == nil {
        panic("This account does not have the required public capability at ".concat(ExampleNFT.CollectionPublicPath.toString()))
    }

    // Step 3: Borrow a reference from the (now non-optional) capability.
    // We use force-unwrap `!` because we just checked that `collectionCap` is not nil.
    let collectionRef = collectionCap!.borrow()
        ?? panic("Could not borrow a reference to the Collection from the capability.")

    let resolver = collectionRef.borrowViewResolver(id: nftID)
        ?? panic("Could not borrow view resolver for NFT with id ".concat(nftID.toString()))

    let displayView = resolver.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
    let traitsView = resolver.resolveView(Type<MetadataViews.Traits>())! as! MetadataViews.Traits

    return NFTData(id: nftID, display: displayView, traits: traitsView)
}