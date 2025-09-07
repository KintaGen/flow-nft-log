import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleToken"
import "FlowToken"

access(all) contract KintaGenNFTPaid: NonFungibleToken {

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    access(all) event LogEntryAdded(nftID: UInt64, agent: String, outputCID: String)
    access(all) event Minted(id: UInt64, agent: String, runHash: String)
    access(all) event ContractInitialized()

    access(all) struct LogEntry {
        access(all) let agent: String
        access(all) let actionDescription: String
        access(all) let outputCID: String
        access(all) let timestamp: UFix64

        init(agent: String, actionDescription: String, outputCID: String) {
            self.agent = agent
            self.actionDescription = actionDescription
            self.outputCID = outputCID
            self.timestamp = getCurrentBlock().timestamp
        }
    }

    access(all) struct WorkflowStepView {
        access(all) let stepNumber: Int
        access(all) let agent: String
        access(all) let action: String
        access(all) let resultCID: String
        access(all) let timestamp: UFix64

        init(stepNumber: Int, agent: String, action: String, resultCID: String, timestamp: UFix64) {
            self.stepNumber = stepNumber
            self.agent = agent
            self.action = action
            self.resultCID = resultCID
            self.timestamp = timestamp
        }
    }

    access(all) fun publicMint(
        payment: @{FungibleToken.Vault},
        agent: String,
        outputCID: String,
        runHash: String
    ): @KintaGenNFTPaid.NFT {
        pre { payment.balance == 1.00: "Incorrect mint payment amount." }
        let receiver = self.getFlowReceiver()
        receiver.deposit(from: <- payment)
        return <- create NFT(agent: agent, outputCID: outputCID, runHash: runHash)
    }

    access(all) view fun getMintPrice(): UFix64 { return 1.00 }

    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {
        access(all) let id: UInt64
        access(all) let initialAgent: String
        access(all) let initialOutputCID: String
        access(all) let initialRunHash: String
        access(all) let initialTimestamp: UFix64
        access(all) var log: [LogEntry]

        init(agent: String, outputCID: String, runHash: String) {
            self.id = self.uuid
            self.initialAgent = agent
            self.initialOutputCID = outputCID
            self.initialRunHash = runHash
            self.initialTimestamp = getCurrentBlock().timestamp
            self.log = []
            emit Minted(id: self.id, agent: self.initialAgent, runHash: self.initialRunHash)
        }

        access(all) fun addLogEntry(agent: String, actionDescription: String, outputCID: String) {
            let e = LogEntry(agent: agent, actionDescription: actionDescription, outputCID: outputCID)
            self.log.append(e)
            emit LogEntryAdded(nftID: self.id, agent: agent, outputCID: outputCID)
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Serial>(),
                Type<[KintaGenNFTPaid.WorkflowStepView]>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    var desc = "Initial State: Created by ".concat(self.initialAgent)
                    var thumb = MetadataViews.IPFSFile(cid: self.initialOutputCID, path: nil)
                    if self.log.length > 0 {
                        let last = self.log[self.log.length - 1]
                        desc = last.actionDescription
                        thumb = MetadataViews.IPFSFile(cid: last.outputCID, path: nil)
                    }
                    return MetadataViews.Display(
                        name: "KintaGen Paid Log #".concat(self.id.toString()),
                        description: desc,
                        thumbnail: thumb
                    )
                case Type<MetadataViews.Traits>():
                    var traits = [
                        MetadataViews.Trait(name: "Initial Agent", value: self.initialAgent, displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "Initial Run Hash", value: self.initialRunHash, displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "Log Entries", value: self.log.length, displayType: "Number", rarity: nil)
                    ]
                    if self.log.length > 0 {
                        traits.append(MetadataViews.Trait(name: "Latest Agent", value: self.log[self.log.length - 1].agent, displayType: "String", rarity: nil))
                    }
                    return MetadataViews.Traits(traits)
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<[KintaGenNFTPaid.WorkflowStepView]>():
                    let story: [WorkflowStepView] = []
                    story.append(WorkflowStepView(
                        stepNumber: 0,
                        agent: self.initialAgent,
                        action: "Created initial data asset",
                        resultCID: self.initialOutputCID,
                        timestamp: self.initialTimestamp
                    ))
                    var i = 0
                    while i < self.log.length {
                        let le = self.log[i]
                        story.append(WorkflowStepView(
                            stepNumber: i + 1,
                            agent: le.agent,
                            action: le.actionDescription,
                            resultCID: le.outputCID,
                            timestamp: le.timestamp
                        ))
                        i = i + 1
                    }
                    return story
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- KintaGenNFTPaid.createEmptyCollection(nftType: Type<@KintaGenNFTPaid.NFT>())
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection, ViewResolver.ResolverCollection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}
        init() { self.ownedNFTs <- {} }
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let nft <- token as! @KintaGenNFTPaid.NFT
            let old <- self.ownedNFTs[nft.id] <- nft
            destroy old
        }
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let nft <- self.ownedNFTs.remove(key: withdrawID) ?? panic("NFT does not exist")
            return <- nft
        }
        access(all) view fun getIDs(): [UInt64] { return self.ownedNFTs.keys }
        access(all) view fun getLength(): Int { return self.ownedNFTs.length }
        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
        }
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? { return nft as &{ViewResolver.Resolver} }
            return nil
        }
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} { return { Type<@KintaGenNFTPaid.NFT>(): true } }
        access(all) view fun isSupportedNFTType(type: Type): Bool { return type == Type<@KintaGenNFTPaid.NFT>() }
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- KintaGenNFTPaid.createEmptyCollection(nftType: Type<@KintaGenNFTPaid.NFT>())
        }
    }

    access(all) resource Minter {
        access(all) fun mint(agent: String, outputCID: String, runHash: String): @NFT {
            return <- create NFT(agent: agent, outputCID: outputCID, runHash: runHash)
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} { return <- create Collection() }

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [Type<MetadataViews.NFTCollectionData>(), Type<MetadataViews.NFTCollectionDisplay>()]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath: self.CollectionPublicPath,
                    publicCollection: Type<&KintaGenNFTPaid.Collection>(),
                    publicLinkedType: Type<&KintaGenNFTPaid.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <- KintaGenNFTPaid.createEmptyCollection(nftType: Type<@KintaGenNFTPaid.NFT>())
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.IPFSFile(cid: "bafkreie6j2nehq5gpcjzymf5qj3txgxgm5xcg2gqzquthy2z2g44zbdvda", path: nil),
                    mediaType: "image/png"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "KintaGen Workflow NFTs (Paid)",
                    description: "Paid-mint NFTs for KintaGen workflow provenance.",
                    externalURL: MetadataViews.ExternalURL("https://kintagen.com"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {}
                )
        }
        return nil
    }

    access(all) fun getFlowReceiver(): &FlowToken.Vault {
        return self.account
            .capabilities
            .get<&FlowToken.Vault>(/public/flowTokenReceiver)
            .borrow()
            ?? panic("Contract account is missing a FlowToken receiver at /public/flowTokenReceiver.")
    }

    init() {
        self.CollectionStoragePath = /storage/kintagenPaidCollection
        self.CollectionPublicPath  = /public/kintagenPaidCollection
        self.MinterStoragePath     = /storage/kintagenPaidMinter

        self.account.storage.save(<- create Minter(), to: self.MinterStoragePath)
        self.account.storage.save(<- create Collection(), to: self.CollectionStoragePath)

        let cap = self.account.capabilities.storage.issue<&KintaGenNFTPaid.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)

        emit ContractInitialized()
    }
}
