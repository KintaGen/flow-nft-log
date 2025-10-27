import PublicKintaGenNFTv2 from 0xf8d6e0586b0a20c7

access(all) fun main(owner: Address, id: UInt64): [PublicKintaGenNFTv2.WorkflowStepView] {
    let collection = getAccount(owner)
        .capabilities
        .borrow<&PublicKintaGenNFTv2.Collection>(PublicKintaGenNFTv2.CollectionPublicPath)
        ?? panic("Account does not expose a PublicKintaGenNFTv2 collection capability")

    let resolver = collection.borrowViewResolver(id: id)
        ?? panic("NFT not found in collection")

    let steps = resolver
        .resolveView(Type<[PublicKintaGenNFTv2.WorkflowStepView]>())!
        as! [PublicKintaGenNFTv2.WorkflowStepView]

    return steps
}
