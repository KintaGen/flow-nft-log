
import KintaGenNFT from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7

access(all) fun main(owner: Address, id: UInt64): MetadataViews.Display {
    let col = getAccount(owner)
        .capabilities
        .get<&KintaGenNFT.Collection>(/public/kintagenNFTCollection)
        .borrow()
        ?? panic("No public KintaGenNFT collection capability")

    let res = col.borrowViewResolver(id: id) ?? panic("NFT not found")
    let anyView = res.resolveView(Type<MetadataViews.Display>()) ?? panic("Display view unavailable")
    return anyView as! MetadataViews.Display
}
