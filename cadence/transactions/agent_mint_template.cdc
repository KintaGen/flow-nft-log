// FILE: cadence/transactions/agent_mint_template.cdc

// This is a template file. The placeholders will be replaced by the Node.js script.
import "Flow" // <-- THIS IS THE CRITICAL FIX
import NonFungibleToken from 0xNON_FUNGIBLE_TOKEN_ADDRESS
import MetadataViews from 0xMETADATA_VIEWS_ADDRESS
import KintaGenNFT from 0xKINTAGEN_NFT_ADDRESS

transaction(recipient: Address, agent: String, outputCID: String, runHash: String) {

    prepare(signer: AuthAccount) {
        // Setup collection if it doesn't exist
        if signer.borrow<&KintaGenNFT.Collection>(from: KintaGenNFT.CollectionStoragePath) == nil {
            signer.save(<-KintaGenNFT.createEmptyCollection(nftType: Type<@KintaGenNFT.NFT>()), to: KintaGenNFT.CollectionStoragePath)
            signer.capabilities.unpublish(KintaGenNFT.CollectionPublicPath)
            let cap = signer.capabilities.storage.issue<&KintaGenNFT.Collection>(KintaGenNFT.CollectionStoragePath)
            signer.capabilities.publish(cap, at: KintaGenNFT.CollectionPublicPath)
            log("KintaGenNFT Collection created for the first time.")
        }
    }

    execute {
        // We borrow from the signer's account, which holds the Minter.
        let minter = getAccount(signer.address).borrow<&KintaGenNFT.Minter>(from: KintaGenNFT.MinterStoragePath)
            ?? panic("Could not borrow a reference to the Minter resource")

        // We borrow the public receiver capability from the recipient.
        let receiver = getAccount(recipient).getCapability(KintaGenNFT.CollectionPublicPath)
            .borrow<&{NonFungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver capability from the recipient's account.")

        let newNFT <- minter.mint(agent: agent, outputCID: outputCID, runHash: runHash)
        receiver.deposit(token: <-newNFT)
        log("NFT Deposited successfully!")
    }
}