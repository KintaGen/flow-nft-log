import PublicKintaGenNFTv2 from 0xf8d6e0586b0a20c7

transaction {
    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        if signer.storage.borrow<&PublicKintaGenNFTv2.Collection>(from: PublicKintaGenNFTv2.CollectionStoragePath) == nil {
            let collection <- PublicKintaGenNFTv2.createEmptyCollection(nftType: Type<@PublicKintaGenNFTv2.NFT>())
            signer.storage.save(<-collection, to: PublicKintaGenNFTv2.CollectionStoragePath)
            signer.capabilities.unpublish(PublicKintaGenNFTv2.CollectionPublicPath)
            let cap = signer.capabilities.storage.issue<&PublicKintaGenNFTv2.Collection>(PublicKintaGenNFTv2.CollectionStoragePath)
            signer.capabilities.publish(cap, at: PublicKintaGenNFTv2.CollectionPublicPath)
        }
    }
}
