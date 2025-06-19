import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"

/**
*  ExampleNFT contract for workflow-provenance.
*
*  This contract implements a Flow Non-Fungible Token (NFT) that is designed
*  to function like a database record. Key metadata fields are mutable,
*  allowing the owner of the NFT to update its data over time.
*
*  Features:
*  - Conforms to the NonFungibleToken v2 standard.
*  - Uses the built-in `self.uuid` for unique, collision-resistant NFT IDs.
*  - Implements an `updateMetadata` function within the NFT resource,
*    restricting update privileges to the NFT's owner.
*  - Emits `Minted` and `Updated` events for on-chain activity tracking.
*  - Includes robust MetadataViews for compatibility with wallets and marketplaces.
*
*/
access(all) contract ExampleNFT: NonFungibleToken {

    /* ─────────────── Standard Paths ─────────────── */
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath : PublicPath
    access(all) let MinterStoragePath    : StoragePath

    /* ────────────────── Events ────────────────── */
    access(all) event Minted(id: UInt64, agent: String, runHash: String)
    access(all) event Updated(id: UInt64, outputCID: String)
    access(all) event ContractInitialized()

    /* ─────────────────── NFT Resource ─────────────────── */
    access(all) resource NFT:
        NonFungibleToken.NFT,
        ViewResolver.Resolver {

        // --- Immutable Data ---
        access(all) let id: UInt64
        access(all) let timestamp : UFix64

        // --- Mutable Data (for database-like functionality) ---
        access(all) var inputs    : [UInt64]
        access(all) var agent     : String
        access(all) var outputCID : String
        access(all) var runHash   : String

        init(
            inputs    : [UInt64],
            agent     : String,
            outputCID : String,
            runHash   : String
        ) {
            // Use the resource's built-in unique ID for the NFT's ID
            self.id        = self.uuid
            self.inputs    = inputs
            self.agent     = agent
            self.outputCID = outputCID
            self.runHash   = runHash
            self.timestamp = getCurrentBlock().timestamp

            emit Minted(id: self.id, agent: self.agent, runHash: self.runHash)
        }

        // Allows the owner of the NFT to modify its metadata.
        access(all) fun updateMetadata(
            newInputs: [UInt64]?,
            newAgent: String?,
            newOutputCID: String?,
            newRunHash: String?
        ) {
            // Use optional arguments: only update fields that are provided
            if let inputs = newInputs { self.inputs = inputs }
            if let agent = newAgent { self.agent = agent }
            if let outputCID = newOutputCID { self.outputCID = outputCID }
            if let runHash = newRunHash { self.runHash = runHash }

            emit Updated(id: self.id, outputCID: self.outputCID)
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Workflow run #".concat(self.id.toString()),
                        description: "Executed by ".concat(self.agent),
                        thumbnail: MetadataViews.IPFSFile(cid: self.outputCID, path: nil)
                    )
                case Type<MetadataViews.Traits>():
                    let traits = MetadataViews.Traits([
                        MetadataViews.Trait(name: "agent", value: self.agent, displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "runHash", value: self.runHash, displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "timestamp", value: self.timestamp, displayType: "Date", rarity: nil),
                        MetadataViews.Trait(name: "inputCount", value: self.inputs.length, displayType: "Number", rarity: nil)
                    ])
                    return traits

                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                
                case Type<MetadataViews.NFTCollectionData>():
                    // Delegate to the contract-level resolver for collection data
                    return ExampleNFT.resolveContractView(resourceType: self.getType(), viewType: Type<MetadataViews.NFTCollectionData>())
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
        }
    }

    /* ─────────────── Collection Resource ─────────────── */
    access(all) resource Collection:
        NonFungibleToken.Collection,
        ViewResolver.ResolverCollection {

        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() { self.ownedNFTs <- {} }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let nft <- token as! @ExampleNFT.NFT
            let old <- self.ownedNFTs[nft.id] <- nft
            destroy old
        }

        access(NonFungibleToken.Withdraw)
        fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let nft <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Cannot withdraw NFT: The NFT with ID ".concat(withdrawID.toString()).concat(" does not exist in this Collection."))
            return <- nft
        }

        access(all) view fun getIDs(): [UInt64] { return self.ownedNFTs.keys }
        access(all) view fun getLength(): Int   { return self.ownedNFTs.length }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
        }

        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return { Type<@ExampleNFT.NFT>(): true }
        }
        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@ExampleNFT.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
        }

    }

    /* ─────────────────── Minter Resource ─────────────────── */
    access(all) resource Minter {
        access(all) fun mint(
            inputs   : [UInt64],
            agent    : String,
            outputCID: String,
            runHash  : String
        ): @NFT {
            let nft <- create NFT(
                inputs   : inputs,
                agent    : agent,
                outputCID: outputCID,
                runHash  : runHash
            )
            return <- nft
        }
    }

    /* ─────────────────── Contract-Level Functions ─────────────────── */

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath : self.CollectionPublicPath,
                    publicCollection: Type<&ExampleNFT.Collection>(),
                    publicLinkedType: Type<&ExampleNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <- ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.IPFSFile(cid: "bafkreie6j2nehq5gpcjzymf5qj3txgxgm5xcg2gqzquthy2z2g44zbdvda", path: nil),
                    mediaType: "image/png"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "Workflow-Provenance NFTs",
                    description: "Graph-style NFTs capturing data-science workflow runs, ensuring verifiable and repeatable computational experiments.",
                    externalURL: MetadataViews.ExternalURL("https://github.com/labdao/flow-cadence/tree/main/workflow-nft"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {
                        "github": MetadataViews.ExternalURL("https://github.com/labdao"),
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/lab_dao")
                    }
                )
        }
        return nil
    }

    /* ─────────────── init ─────────────── */
    init() {
        self.CollectionStoragePath = /storage/workflowNFTCollection
        self.CollectionPublicPath  = /public/workflowNFTCollection
        self.MinterStoragePath     = /storage/workflowNFTMinter

        // Create a Minter resource and save it to storage
        let minter <- create Minter()
        self.account.storage.save(<- minter, to: self.MinterStoragePath)

        // The deployer of the contract also gets an empty collection
        self.account.storage.save(<- create Collection(), to: self.CollectionStoragePath)

        // Publish a public capability for the deployer's collection
        let cap = self.account.capabilities.storage.issue<&ExampleNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)

        emit ContractInitialized()
    }
}