import PublicKintaGenNFTv2 from 0xf8d6e0586b0a20c7

access(all) fun main(address: Address, id: UInt64): [String] {
    let collection = getAccount(address)
        .capabilities
        .borrow<&PublicKintaGenNFTv2.Collection>(PublicKintaGenNFTv2.CollectionPublicPath)
        ?? panic("Account does not expose a PublicKintaGenNFTv2 collection.")

    let resolver = collection.borrowViewResolver(id: id)
        ?? panic("Could not borrow view resolver for the requested NFT.")

    let steps = resolver
        .resolveView(Type<[PublicKintaGenNFTv2.WorkflowStepView]>())!
        as! [PublicKintaGenNFTv2.WorkflowStepView]

    var titles: [String] = []
    var i = 0
    while i < steps.length {
        titles.append(steps[i].title)
        i = i + 1
    }
    return titles
}
