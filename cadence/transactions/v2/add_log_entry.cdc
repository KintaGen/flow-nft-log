import PublicKintaGenNFTv2 from 0xf8d6e0586b0a20c7

transaction(nftID: UInt64, agent: String, title: String, details: String, cid: String) {
    prepare(signer: auth(BorrowValue) &Account) {
        let collection = signer.storage.borrow<&PublicKintaGenNFTv2.Collection>(from: PublicKintaGenNFTv2.CollectionStoragePath)
            ?? panic("Signer does not own a PublicKintaGenNFTv2 collection.")

        let nft = collection.borrowNFT(nftID)! as! &PublicKintaGenNFTv2.NFT
        nft.addLogEntry(agent: agent, title: title, description: details, ipfsHash: cid)
    }
}
