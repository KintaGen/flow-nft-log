import "KintaGenNFTPaid"
import "FlowToken"
import "FungibleToken"

transaction(agent: String, outputCID: String, runHash: String) {
    prepare(signer: auth(BorrowValue) &Account) {
        let vault: auth(FungibleToken.Withdraw) &FlowToken.Vault =
            signer.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Missing FlowToken Vault. Run setup_user_paid.cdc first.")

        let payment <- vault.withdraw(amount: 1.00)

        let nft <- KintaGenNFTPaid.publicMint(
            payment: <- payment,
            agent: agent,
            outputCID: outputCID,
            runHash: runHash
        )

        let collection = signer.storage
            .borrow<&KintaGenNFTPaid.Collection>(from: /storage/kintagenPaidCollection)
            ?? panic("Missing KintaGenNFTPaid Collection. Run setup_user_paid.cdc first.")
        collection.deposit(token: <- nft)
    }
}
