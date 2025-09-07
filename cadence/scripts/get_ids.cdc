import KintaGenNFT from 0xf8d6e0586b0a20c7

access(all) fun main(owner: Address): [UInt64] {
    let col = getAccount(owner)
        .capabilities
        .get<&KintaGenNFT.Collection>(/public/kintagenNFTCollection)
        .borrow()
        ?? panic("No public KintaGenNFT collection capability")
    return col.getIDs()
}
