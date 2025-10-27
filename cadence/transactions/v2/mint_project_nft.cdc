import NonFungibleToken from 0xf8d6e0586b0a20c7
import PublicKintaGenNFTv2 from 0xf8d6e0586b0a20c7

transaction(
    recipient: Address,
    project: String,
    summary: String,
    cid: String,
    investigator: String,
    runHash: String
) {
    let minter: &PublicKintaGenNFTv2.Minter
    let receiver: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        self.minter = signer.storage.borrow<&PublicKintaGenNFTv2.Minter>(from: PublicKintaGenNFTv2.MinterStoragePath)
            ?? panic("PublicKintaGenNFTv2 minter not found in storage.")

        self.receiver = getAccount(recipient)
            .capabilities
            .borrow<&{NonFungibleToken.Receiver}>(PublicKintaGenNFTv2.CollectionPublicPath)
            ?? panic("Recipient does not expose a KintaGen collection receiver.")
    }

    execute {
        let token <- self.minter.mint(
            projectName: project,
            projectSummary: summary,
            projectCID: cid,
            principalInvestigator: investigator,
            runHash: runHash
        )
        self.receiver.deposit(token: <-token)
    }
}
