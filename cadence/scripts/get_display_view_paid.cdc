import "KintaGenNFTPaid"
import "MetadataViews"

access(all) fun main(owner: Address, id: UInt64): MetadataViews.Display {
    let col = getAccount(owner)
        .capabilities
        .get<&KintaGenNFTPaid.Collection>(/public/kintagenPaidCollection)
        .borrow()
        ?? panic("No public KintaGenNFTPaid collection capability")

    let res = col.borrowViewResolver(id: id) ?? panic("NFT not found")
    let anyView = res.resolveView(Type<MetadataViews.Display>()) ?? panic("Display view unavailable")
    return anyView as! MetadataViews.Display
}
