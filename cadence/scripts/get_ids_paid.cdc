import "KintaGenNFTPaid"

access(all) fun main(owner: Address): [UInt64] {
    let col = getAccount(owner)
        .capabilities
        .get<&KintaGenNFTPaid.Collection>(/public/kintagenPaidCollection)
        .borrow()
        ?? panic("No public KintaGenNFTPaid collection capability")
    return col.getIDs()
}
